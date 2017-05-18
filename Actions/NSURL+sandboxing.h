//
//  NSURL+sandboxing.h
//  Actions
//
//  Created by Lukas Bischof on 26.06.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (sandboxing)

- (void)accessResourceUsingBlock:(void(^)(void))block;

@end
