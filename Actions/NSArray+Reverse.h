//
//  NSArray+Reverse.h
//  Actions
//
//  Created by Lukas Bischof on 29.01.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface NSArray (Reverse)

- (NSArray *)invertedArray;

@end

@interface NSMutableArray (Reverse)

- (void)invert;

@end
