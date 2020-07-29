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

+ (CPUStaticInformation *)sharedInfo {
    static CPUStaticInformation *info;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        info = [[CPUStaticInformation alloc] init];
    });

    return info;
}

- (float)determineCPUFrequency {
    int mib[2] = {CTL_HW, HW_CPU_FREQ};
    unsigned int freq;
    size_t len = sizeof(freq);

    sysctl(mib, 2, &freq, &len, NULL, 0);

    return (float)(freq / ONE_GHZ);
}

- (NSString *)determineCPUBrandName {
    char brand[100];
    size_t buffer_length = sizeof(brand);
    sysctlbyname("machdep.cpu.brand_string", &brand, &buffer_length, NULL, 0);

    return [NSString stringWithCString:brand encoding:NSUTF8StringEncoding];
}

- (instancetype)init {
    if ((self = [super init])) {
        _frequency = [self determineCPUFrequency];
        _brand = [self determineCPUBrandName];
    }

    return self;
}

@end
