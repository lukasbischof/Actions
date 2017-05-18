//
//  NSApplication+relaunch.h
//  Actions
//
//  Created by Lukas Bischof on 22.12.14.
//  Copyright (c) 2014 Lukas. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSApplication (relaunch)

- (void)relaunchAfterDelay:(float)seconds;

@end
