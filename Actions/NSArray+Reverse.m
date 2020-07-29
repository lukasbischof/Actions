//
//  NSArray+Reverse.m
//  Actions
//
//  Created by Lukas Bischof on 29.01.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "NSArray+Reverse.h"

@implementation NSArray (Reverse)

- (NSArray *)invertedArray {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self count]];
    NSEnumerator *enumerator = [self reverseObjectEnumerator];
    for (id element in enumerator) {
        [array addObject:element];
    }
    return array;
}

@end

@implementation NSMutableArray (Reverse)

- (void)invert {
    if (self.count <= 1)
        return;

    NSUInteger i = 0;
    NSUInteger j = self.count - 1;
    while (i < j) {
        [self exchangeObjectAtIndex:i
                  withObjectAtIndex:j];

        i++;
        j--;
    }
}

@end
