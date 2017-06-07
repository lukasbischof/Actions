//
//  CPUStaticInformation.h
//  Actions
//
//  Created by Lukas Bischof on 07.06.17.
//  Copyright © 2017 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CPUStaticInformation : NSObject

/**
 @property frequency
 @abstract The CPU base frequency in GHz
*/
@property (assign, nonatomic, readonly) float frequency;

/**
 @property brand
 @abstract The CPU brand as string
*/
@property (strong, nonatomic, readonly) NSString *brand;

+ (CPUStaticInformation *)sharedInfo;

@end
