//
//  NSApplication+relaunch.m
//  Actions
//
//  Created by Lukas Bischof on 22.12.14.
//  Copyright (c) 2014 Lukas. All rights reserved.
//

#import "NSApplication+relaunch.h"

@implementation NSApplication (relaunch)

- (void)relaunchAfterDelay:(float)seconds {
    NSTask *task = [[NSTask alloc] init];
    NSMutableArray *args = [NSMutableArray array];
    [args addObject:@"-c"];
    [args addObject:[NSString stringWithFormat:@"sleep %f; open \"%@\"", seconds, [[NSBundle mainBundle] bundlePath]]];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:args];
    [task launch];

    [self terminate:nil];
}

@end
