//
//  CPUStaticInformation.m
//  Actions
//
//  Created by Lukas Bischof on 07.06.17.
//  Copyright © 2017 Lukas. All rights reserved.
//

#import "CPUStaticInformation.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#define ONE_GHZ 1000000000.0

@implementation CPUStaticInformation

+ (CPUStaticInformation *)sharedInfo
{
    static CPUStaticInformation *info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        info = [[CPUStaticInformation alloc] init];
    });
    
    return info;
}

- (instancetype)init
{
    if ((self = [super init])) {
        int mib[2] = { CTL_HW, HW_CPU_FREQ };
        unsigned int freq;
        size_t len = sizeof(freq);
        
        sysctl(mib, 2, &freq, &len, NULL, 0);
        
        _frequency = (float)freq / ONE_GHZ;
        
        char brand[100];
        size_t buffer_length = sizeof(brand);
        sysctlbyname("machdep.cpu.brand_string", &brand, &buffer_length, NULL, 0);
        
        _brand = [NSString stringWithCString:brand encoding:NSUTF8StringEncoding];
    }
    
    return self;
}

@end
