//
//  RediiCore.h
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013 xinranmsn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RediiAudio.h"
#import "RediiCoder.h"

// Notification definition
NSString *const RediiCoreInitializedNotification;
NSString *const RediiCoreStatusChangedNotification;

typedef enum _RediiCoreStatus {
    RediiCoreStatusDisconnected = 0,
    RediiCoreStatusConnectedWithError,
    RediiCoreStatusConnected,
} RediiCoreStatus;

@interface RediiCore : NSObject <RediiAudioDelegate> {
    RediiAudio *_audio;
    RediiCoder *_coder;
}

@property (nonatomic, readonly) RediiCoreStatus status;
@property (nonatomic, readonly) RediiAudio *audio;
@property (nonatomic, readonly) RediiCoder *coder;

+ (RediiCore *)sharedCore;

// Raw APIs
- (void)sendRawCommand:(void *)command;
- (void)sendRawData:(void *)data;

// Read APIs
- (double)readTemperature;

// Send APIs
- (void)sendIRCommand:(void *)cmd;

@end
