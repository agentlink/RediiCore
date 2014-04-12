//
//  RediiAudio.m
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013 xinranmsn. All rights reserved.
//

#import "RediiAudio.h"

@interface RediiAudio () {
   
}

@end

@implementation RediiAudio

- (id)init
{
    self = [super init];
    if (self) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        
        // Initialize outlet quick access
        _portType = @"";
        
        [self updateStatus];
    }
    return self;
}

- (void)audioRouteChanged:(NSNotification *)aNotification
{
    [self updateStatus];
    [self.delegate rediiAudioDeviceStatusChanged:_status];
    NSLog(@"Route changed!");
}

- (void)updateStatus
{
    if ([[AVAudioSession sharedInstance] inputIsAvailable]) {
        // Get port description
        NSArray *inputs = [[[AVAudioSession sharedInstance] currentRoute] inputs];
        AVAudioSessionPortDescription *desc = (AVAudioSessionPortDescription *)inputs[0];
        NSLog(@"Input port name: %@", desc.portName);
        
        // Update outlet quick access to portType
        _portType = [NSString stringWithString:desc.portType];
        
        // Check audio availability
        if ([desc.portType isEqualToString:AVAudioSessionPortHeadsetMic]) {
            _status = RediiAudioDeviceStatusPlugged;
        }
        else {
            _status = RediiAudioDeviceStatusUnplugged;
        }
    }
    
    // Boy you are on simulator!
    else {
        _status = RediiAudioDeviceStatusNone;
        NSLog(@"No input device!");
    }
}

#pragma mark - Audio Send



OSStatus SquareWaveRenderCallback(void * inRefCon,
                                AudioUnitRenderActionFlags * ioActionFlags,
                                const AudioTimeStamp * inTimeStamp,
                                UInt32 inBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList * ioData)
{
    // inRefCon is the context pointer we passed in earlier when setting the render callback
    void data = *((void *)inRefCon);
    // ioData is where we're supposed to put the audio samples we've created
    Float32 * outputBuffer = (Float32 *)ioData->mBuffers[0].mData;
    const double frequency = 440.;
    const double phaseStep = (frequency / 44100.) * (M_PI * 2.);
    
    for(int i = 0; i < inNumberFrames; i++) {
        outputBuffer[i] = sin(currentPhase);
        currentPhase += phaseStep;
    }
    
    // writing the current phase back to inRefCon so we can use it on the next call
    *((double *)inRefCon) = currentPhase;
    return noErr;
}


@end
