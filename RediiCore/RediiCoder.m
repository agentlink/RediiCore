//
//  RediiCoder.m
//  RediiCore
//
//  Created by Richard Wei on 10/15/13.
//  Copyright (c) 2013-2014 xinranmsn. All rights reserved.
//

#import "RediiCoder.h"

@implementation RediiCoder

static RediiCoder *_instance;

+ (RediiCoder *)coder
{
    if (_instance == nil) {
        _instance = [[self alloc] init];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

// Rarely used. Not need to implement.
- (id)initWithData:(void *)data
{
    if ((self = [super init])) {
        
    }
    return self;
}

@end
