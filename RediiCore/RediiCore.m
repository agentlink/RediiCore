//
//  RediiCore.m
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013 xinranmsn. All rights reserved.
//

#import "RediiCore.h"

static RediiCore *_instance;

NSString *const RediiCoreInitializedNotification = @"RediiCoreInitializedNotification";
NSString *const RediiCoreStatusChangedNotification = @"RediiCoreStatusChangedNotification";

@interface RediiCore ()

- (void)updateStatusWithAudioDeviceStatus:(RediiAudioDeviceStatus)ads;

@end

@implementation RediiCore

+ (RediiCore *)sharedCore
{
    if (_instance == nil) {
        _instance = [[self alloc] init];
    }
    return _instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _audio = [[RediiAudio alloc] init];
        _audio.delegate = self;
        _coder = [[RediiCoder alloc] init];
        [self updateStatusWithAudioDeviceStatus:_audio.status];
        [[NSNotificationCenter defaultCenter] postNotificationName:RediiCoreInitializedNotification object:nil];
    }
    return self;
}

- (void)updateStatusWithAudioDeviceStatus:(RediiAudioDeviceStatus)ads
{
    if (ads == RediiAudioDeviceStatusPlugged) {
        // Should connect
        // ...
        // Test for pluggedness
        _status = RediiCoreStatusConnected;
    }
    else if (ads == RediiAudioDeviceStatusUnplugged) {
        _status = RediiCoreStatusDisconnected;
    }
}

#pragma mark - Redii Audio Delegate

- (void)rediiAudioDeviceStatusChanged:(RediiAudioDeviceStatus)status
{
    // if status doesn't affect working, pass
    // if does, then ↓
    [self updateStatusWithAudioDeviceStatus:status];
    [[NSNotificationCenter defaultCenter] postNotificationName:RediiCoreStatusChangedNotification object:nil];
}

#pragma mark - Redii Audio Delegate

- (void)sendRawCommand:(void *)command
{
    // Raw Command in 8-bits
    // Not implementing with RediiCoder
    // Directly send to audio!
}

- (void)sendRawData:(void *)data
{
    
}



@end
