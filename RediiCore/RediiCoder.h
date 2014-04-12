//
//  RediiCoder.h
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013-2014 xinranmsn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface RediiCoder : NSObject {
    void *_data;
}

// Singleton
+ (RediiCoder *)coder;

// Initialization
- (id)initWithData:(void *)data;

// APIs

@end
