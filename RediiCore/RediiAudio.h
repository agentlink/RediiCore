//
//  RediiAudio.h
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013 xinranmsn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    RediiAudioDeviceStatusNone = 0,
    RediiAudioDeviceStatusUnplugged,
    RediiAudioDeviceStatusPlugged,
} RediiAudioDeviceStatus;

@protocol RediiAudioDelegate;

@interface RediiAudio : NSObject {
}

@property (nonatomic, unsafe_unretained) id <RediiAudioDelegate> delegate;
@property (nonatomic) RediiAudioDeviceStatus status;
@property (nonatomic, strong, readonly) NSString *portType;

- (void)sendCommand:(void *)cmd;

@end


@protocol RediiAudioDelegate

- (void)rediiAudioDeviceStatusChanged:(RediiAudioDeviceStatus)status;

@end
