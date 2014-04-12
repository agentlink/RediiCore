/*
 Copyright (c) Kevin P Murphy June 2012
 */

#import "AudioController.h"


//I/O bus enum
#define kOutputBus 0
#define kInputBus 1

//MIDI constants:
enum {
	kMIDIMessage_NoteOn    = 0x9,
	kMIDIMessage_NoteOff   = 0x8,
};


@implementation AudioController
@synthesize audioFormat, delegate, input, output, sampleRate, mixerUnit, samplerUnit, ioUnit, audioGraph;

+ (AudioController *) sharedAudioManager
{
    static AudioController *sharedAudioManager;
    
    @synchronized(self)
    {
        if (!sharedAudioManager) {
            sharedAudioManager = [[AudioController alloc] init];
        }
        return sharedAudioManager;
    }
}

void checkStatus(OSStatus status) {
    if(status!=0)
        printf("Error: %ld\n", status);
}

void silenceData(AudioBufferList *inData)
{
	for (UInt32 i=0; i < inData->mNumberBuffers; i++)
		memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
}

- (float) sampleRate {
    return self.audioFormat.mSampleRate;
}

#pragma mark init

- (id)init
{
    [self createAUGraph];
    
    //Initialize Audio Session
    OSStatus status;
    status = AudioSessionInitialize(NULL, NULL, NULL, (__bridge void*) self);
    checkStatus(status);
    
    //Setup the Remote I/O unit for recording (not in the AUGraph).
    //Enable IO for recording
    UInt32 flag = 1;
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO, 
                                  kAudioUnitScope_Input, 
                                  kInputBus,
                                  &flag,
                                  sizeof(flag));
    checkStatus(status);
    
    //Describe format
    audioFormat.mSampleRate= 44100.0;
    audioFormat.mFormatID= kAudioFormatLinearPCM;
    audioFormat.mFormatFlags= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket= 1;
    audioFormat.mChannelsPerFrame= 1;
    audioFormat.mBitsPerChannel= 16;
    audioFormat.mBytesPerPacket= 2;
    audioFormat.mBytesPerFrame= 2;
    
    //Apply format to both the input and output channels
    //Input (scope is set to output because we want to change the format as the audio signal comes OUT of the microphone and into our callback function)
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioUnitProperty_StreamFormat, 
                                  kAudioUnitScope_Output, 
                                  kInputBus, 
                                  &audioFormat, 
                                  sizeof(audioFormat));
    checkStatus(status);
    
    //Output (the scope is set to input because we want to change the format as the audio signal leaves our callback and goes INTO the speaker)
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioUnitProperty_StreamFormat, 
                                  kAudioUnitScope_Input, 
                                  kOutputBus, 
                                  &audioFormat, 
                                  sizeof(audioFormat));
    checkStatus(status);
    
    //Set input callback - used for recording. 
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = recordingCallback;
    callbackStruct.inputProcRefCon = (__bridge void*)self; //since the callback is a C function, we can't obtain instance variables of this AudioController object. So you can set this 'inputProcRefCon' variable to 'self'. This probably stands for something like "Input Process - Reference to the Context", essentialy it allows you to access the rest of the App's context in this C function.
    //Set output callback - used for synthesis/playback.
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback, 
                                  kAudioUnitScope_Global, 
                                  kInputBus, 
                                  &callbackStruct, 
                                  sizeof(callbackStruct));
    checkStatus(status);
    
    
    //Disable buffer allocation for the recorder
    flag = 0;
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Global, kInputBus, &flag, sizeof(flag));
    
    //Set the audio session. There are about 8 different categories and they each describe the behavior of the audio session. For example, does it pause other audio sessions or mix with them? Does it use VOIP, or even the microphone? For our example I'll just use PlayAndRecord because it allows you to do just that. I'd say this is the most flexible of them all, as it allows you to just mute the output channel or ignore the input channel if you don't need it. Look online at Apples AudioSession documentation. (you could probably just highlight "kAudioSessionProperty_AudioCategory", right click and go to "jump to definition" to see some documentation).
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    checkStatus(status);
    
    //Set the sample rate of the AUSampler unit. This is one of the few types of audio units availbe to iOS, and it allows you to load samples that can be played by say, a keyboard on screen, randomly by your app in response to user input, or an external MIDI keyboard. The possibilities are endless! In order to play them I have set up the convenience methods -startNote and -stopNote. More on that later
    status = 0;
    UInt32 sampleRatePropertySize = sizeof(self.sampleRate);
    float samplerRate = self.sampleRate;
    status = AudioUnitSetProperty(self.samplerUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &samplerRate, sampleRatePropertySize);
    checkStatus(status);
    
    //Set FramesPerSlice to 0 so the device decides
    UInt32 framesPerSlice = 0;
    UInt32 framesPerSlicePropertySize = sizeof (framesPerSlice);
    status = 0;
    status = AudioUnitGetProperty(self.ioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &framesPerSlice, &framesPerSlicePropertySize);
    checkStatus(status);
    
    //Do the same for the sampler unit
    status = 0;
    status = AudioUnitSetProperty(self.samplerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &framesPerSlice, framesPerSlicePropertySize);
    checkStatus(status);
    
    //Was the AUGraph set up properly? All systems go? Let's start this bad boy up.
    if (self.audioGraph) {
        //Initialize and Start
        status = AUGraphInitialize(self.audioGraph);
        checkStatus(status);
        status = AUGraphStart(self.audioGraph);
        checkStatus(status);
        
        //Printing the graph gives you some information in the output console.
        CAShow(self.audioGraph);
    }
    
    //Set the Session active (we had just initialized it earlier)
    status = AudioSessionSetActive(YES);
    checkStatus(status);
    
    //Initialize the Remote IO unit 
    status = AudioUnitInitialize(ioUnit);
    checkStatus(status);
    
    //Configure the Mixer (its easier to imagine a large mixing board with the following lines of code. Each channel has an input bus, it is either on or off, and has a gain (the sliders at the bottom of each channel). And the whole board has a main slider for the output gain)
    [self enableMixerInput: 0 isOn: YES];
    [self enableMixerInput: 1 isOn: YES];
    
    [self setMixerOutputGain: 0.5];
    
    [self setMixerInput: 0 gain: 0.5];
    [self setMixerInput: 1 gain: 0.5];

    //Load a SF2 patch (in this case a piano SF2 I found after a google search for "Free unlicensed SF2")
    [self loadFromDLSOrSoundFontName:@"Claudio_Piano" withPatch:0];
    
    return self;
}


- (BOOL) createAUGraph {
	OSStatus result = noErr;
    
    //Create a new AUGraph
	result = NewAUGraph(&audioGraph);
    checkStatus(result);
    
    //Set up the nodes for the graph. Basically the sampler node and ioNode(input) connect to the mixer node, which connects back to the ioUnit (output)
	AUNode samplerNode, mixerNode, ioNode;    
    
	//Description of the Sampler Unit
    AudioComponentDescription samplerUnitDescription;
	samplerUnitDescription.componentManufacturer     = kAudioUnitManufacturer_Apple;
	samplerUnitDescription.componentFlags            = 0;
	samplerUnitDescription.componentFlagsMask        = 0;
	samplerUnitDescription.componentType             = kAudioUnitType_MusicDevice;
	samplerUnitDescription.componentSubType          = kAudioUnitSubType_Sampler;
	
    // Add the Sampler unit node to the graph
	result = AUGraphAddNode (self.audioGraph, &samplerUnitDescription, &samplerNode);
    checkStatus(result);
    
    //Description of the Mixer Unit
    AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType          = kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags         = 0;
    mixerUnitDescription.componentFlagsMask     = 0;
    
    result = AUGraphAddNode(self.audioGraph, &mixerUnitDescription, &mixerNode);
    checkStatus(result);
    
	// Specify the Output unit, to be used as the second and final node of the graph
    AudioComponentDescription ioUnitDescription;
	ioUnitDescription.componentManufacturer     = kAudioUnitManufacturer_Apple;
	ioUnitDescription.componentFlags            = 0;
	ioUnitDescription.componentFlagsMask        = 0;
	ioUnitDescription.componentType             = kAudioUnitType_Output;
	ioUnitDescription.componentSubType          = kAudioUnitSubType_RemoteIO;
    
    //Add the Output unit node to the graph
	result = AUGraphAddNode (self.audioGraph, &ioUnitDescription, &ioNode);
    checkStatus(result);
    
    //Open the graph
	result = AUGraphOpen (self.audioGraph);
    checkStatus(result);    
    
	//Obtain a reference to the Sampler unit
	result = AUGraphNodeInfo(self.audioGraph, samplerNode, 0, &samplerUnit);
    checkStatus(result);
    
    //Obtain a reference to the Mixer unit
    result = AUGraphNodeInfo(self.audioGraph, mixerNode, 0, &mixerUnit);
    checkStatus(result);
    
	//Obtain a reference to the Remote I/O unit
	result = AUGraphNodeInfo (self.audioGraph, ioNode, 0, &ioUnit);
    checkStatus(result);
    
    ////Connect all of the nodes and set up the mixer unit
    //Set the bus count - we need two channels going into the mixer, one for the sampler unit, and one for our callback function
    UInt32 busCount = 2;
    result = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
    
    //Define the format going into the mixer for each channel
    AudioStreamBasicDescription monoStreamFormat;
    monoStreamFormat.mSampleRate= 44100;
    monoStreamFormat.mFormatID= kAudioFormatLinearPCM;
    monoStreamFormat.mFormatFlags= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    monoStreamFormat.mFramesPerPacket= 1;
    monoStreamFormat.mChannelsPerFrame= 1;
    monoStreamFormat.mBitsPerChannel= 16;
    monoStreamFormat.mBytesPerPacket= 2;
    monoStreamFormat.mBytesPerFrame= 2;
    
    result = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &monoStreamFormat, sizeof(monoStreamFormat));
    checkStatus(result);
    
    result = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &monoStreamFormat, sizeof (monoStreamFormat));
    checkStatus(result);
    
    //Connect the nodes
    result = AUGraphConnectNodeInput(self.audioGraph, samplerNode, 0, mixerNode, 0);
    checkStatus(result);
	result = AUGraphConnectNodeInput (self.audioGraph, mixerNode, 0, ioNode, 0);
    checkStatus(result);
    
    // Attach the input render callback and context to each input bus
    // Setup the struture that contains the input render callback
    AURenderCallbackStruct inputCallbackStruct;
    inputCallbackStruct.inputProc        = &playbackCallback;
    inputCallbackStruct.inputProcRefCon  = (__bridge void*) self;
    
    // Set a callback for the specified node's specified input
    result = AUGraphSetNodeInputCallback(self.audioGraph, mixerNode, 1, &inputCallbackStruct);
    checkStatus(result);
    
    return YES;
}

#pragma mark - Sampler Unit/MIDI Control -

-(OSStatus) loadFromDLSOrSoundFontName: (NSString *)name withPatch: (int)presetNumber {
    
    //Get an NSURL of the SF2 file with a specified name
    NSURL *bankURL;
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"sf2"];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        bankURL = [[NSURL alloc] initFileURLWithPath:path];
    } else {
		NSLog(@"ERROR: Could not get PRESET URL");
    }
    
    OSStatus result = noErr;
    //Fill out a blank AUSample preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) presetNumber;
    
    // set the kAUSamplerProperty_LoadPresetFromBank property
    result = AudioUnitSetProperty(self.samplerUnit, kAUSamplerProperty_LoadPresetFromBank, kAudioUnitScope_Global, 0, &bpdata, sizeof(bpdata));
    
    NSCAssert2(result==noErr, @"Unable to set SF2 on Sampler...  Error code:%d '%.4s", (int) result,  (const char*) &result);
    
    return result;
}

- (void) playNote:(int) notenumm {
    UInt32 noteNum = notenumm;
	UInt32 onVelocity = 100;
	UInt32 noteCommand = 	kMIDIMessage_NoteOn << 4 | 0;
	
    OSStatus result = noErr;
    result = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, onVelocity, 0);
    checkStatus(result);
}

- (void) stopNote:(int) notenumm {
    UInt32 noteNum = notenumm;
	UInt32 onVelocity = 100;
	UInt32 noteCommand = 	kMIDIMessage_NoteOff << 4 | 0;
	
    OSStatus result = noErr;
    result = MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, onVelocity, 0);
    checkStatus(result);
}


#pragma mark - Callbacks -
//This is where audio comes into your app for recording (recording callback) and leaves for playback (playbackCallback).

static OSStatus playbackCallback (void *inRefCon, AudioUnitRenderActionFlags  *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    //This function asks you to produce a "inNumberFrames" amount of samples and place them in ioData, they will soon be played by the speaker.
    
    AudioController *THIS = (__bridge AudioController*) inRefCon;
    SInt16 *temp = (SInt16 *) ioData->mBuffers[0].mData;
    

    if(!THIS.output) {
        memset(temp, 0, inNumberFrames*sizeof(SInt16));
        return noErr;
    } else {
        [THIS.delegate audioOutputNeedsSamples:temp length:inNumberFrames];
    }
    
    return noErr;
}


static OSStatus recordingCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    //This function alerts you that the newest input samples are available and you should call AudioUnitRender to do stuff with them
    AudioController *THIS = (__bridge AudioController*) inRefCon;
    
    if(!THIS.input) return noErr;
    
    THIS->bufferList.mNumberBuffers = 1;
    THIS->bufferList.mBuffers[0].mDataByteSize = sizeof(SInt16)*inNumberFrames;
    THIS->bufferList.mBuffers[0].mNumberChannels = 1;
    THIS->bufferList.mBuffers[0].mData = (SInt16*) malloc(sizeof(SInt16)*inNumberFrames);
    
    OSStatus status;
    status = AudioUnitRender(THIS.ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &(THIS->bufferList));
    checkStatus(status);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [THIS.delegate receivedAudioSamples:(SInt16*)THIS->bufferList.mBuffers[0].mData length:inNumberFrames];
    });
    
    return noErr;
}

#pragma mark - Mixer unit -
// Enable or disable a specified bus
- (void) enableMixerInput: (UInt32) inputBus isOn: (AudioUnitParameterValue) isOnValue {
    OSStatus result = AudioUnitSetParameter (mixerUnit,
                                             kMultiChannelMixerParam_Enable,
                                             kAudioUnitScope_Input,
                                             inputBus,
                                             isOnValue,
                                             0);
    checkStatus(result);
}

// Set the mixer unit input volume for a specified bus
- (void) setMixerInput: (UInt32) inputBus gain: (AudioUnitParameterValue) newGain {
    OSStatus result = AudioUnitSetParameter (mixerUnit,
                                             kMultiChannelMixerParam_Volume,
                                             kAudioUnitScope_Input,
                                             inputBus,
                                             newGain,
                                             0);
    checkStatus(result);
}

// Set the mxer unit output volume
- (void) setMixerOutputGain: (AudioUnitParameterValue) newGain {
    OSStatus result = AudioUnitSetParameter (mixerUnit,
                                             kMultiChannelMixerParam_Volume,
                                             kAudioUnitScope_Output,
                                             0,
                                             newGain,
                                             0);
    checkStatus(result);
}


@end
