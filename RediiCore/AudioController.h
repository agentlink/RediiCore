/*
 Copyright (c) Kevin P Murphy June 2012
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AudioManagerDelegate
@required
- (void) receivedAudioSamples:(SInt16*) samples length:(int) len;
- (void) audioOutputNeedsSamples:(SInt16*) sample length:(int) len;
@end

@interface AudioController : NSObject
{
    @public
    AudioBufferList bufferList;
}
@property (readwrite) BOOL input, output;
@property (nonatomic, readwrite) float sampleRate;
@property (nonatomic, assign) AudioStreamBasicDescription audioFormat;
@property (readwrite) AUGraph   audioGraph;
@property (readwrite) AudioUnit samplerUnit;
@property (readwrite) AudioUnit mixerUnit;
@property (readwrite) AudioUnit ioUnit;
@property (nonatomic, assign) id<AudioManagerDelegate> delegate;

+ (AudioController*) sharedAudioManager;
- (void) playNote:(int) notenum;
- (void) stopNote:(int) notenum;
- (OSStatus) loadSynthFromPresetURL: (NSURL *) presetURL;
- (OSStatus) loadFromDLSOrSoundFontName: (NSString *)name withPatch: (int)presetNumber;


@end




