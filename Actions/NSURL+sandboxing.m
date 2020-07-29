//
//  NSURL+sandboxing.m
//  Actions
//
//  Created by Lukas Bischof on 26.06.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "NSURL+sandboxing.h"
#import "Actions-Swift.h"

@implementation NSURL (sandboxing)

- (void)accessResourceUsingBlock:(void (^)(void))block {
    if ([SettingsKVStore sharedStore].appIsSandboxed) {
        [self startAccessingSecurityScopedResource];
    }

    block();

    if ([SettingsKVStore sharedStore].appIsSandboxed) {
        [self stopAccessingSecurityScopedResource];
    }
}

@end
