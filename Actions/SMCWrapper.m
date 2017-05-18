//
//  SMCWrapper.m
//  Actions
//
//  Created by Lukas Bischof on 03.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "SMCWrapper.h"
#import "Actions-Swift.h"

#ifndef SWF
#define SWF(string, ...) [NSString stringWithFormat:string, ##__VA_ARGS__]
#endif

#pragma mark - POWER INFO
/* ********************************************************** */
/* **************|         PWR INFO         |**************** */
/* ********************************************************** */

@interface SMCPowerInfo ()

- (instancetype)initWithTotalSystemDCIN:(double)totalDCIN;

@end

@implementation SMCPowerInfo

- (instancetype)initWithTotalSystemDCIN:(double)totalDCIN
{
    if ((self = [super init])) {
        _totalSystemDC_IN = totalDCIN;
    }
    
    return self;
}

@end



#pragma mark - CPU INFO
/* ********************************************************** */
/* **************|         CPU INFO         |**************** */
/* ********************************************************** */

@interface SMCCPUInfo ()

- (nonnull instancetype)initWithTemp:(double)temp;

@end

@implementation SMCCPUInfo

- (instancetype)initWithTemp:(double)temp
{
    if ((self = [super init])) {
        _temperature = temp;
    }
    
    return self;
}

- (double)tempInFarenheit
{
    return _temperature * 1.8 + 32.0;
}

- (NSString *)description
{
    return SWF(@"<SMCCPUInfo %p; temperature: %.3f°C>", self, _temperature);
}

@end



#pragma mark - FAN INFO
/* ********************************************************** */
/* **************|         FAN INFO         |**************** */
/* ********************************************************** */

@interface SMCFanInfo ()

- (instancetype)initWithID:(const char *)ID
               actualSpeed:(float)act
              minimumSpeed:(float)min
              maximumSpeed:(float)max
                 safeSpeed:(float)safe
               targetSpeed:(float)target
                   andMode:(int)mode;

@end

@implementation SMCFanInfo

- (instancetype)initWithID:(const char *)ID
               actualSpeed:(float)act
              minimumSpeed:(float)min
              maximumSpeed:(float)max
                 safeSpeed:(float)safe
               targetSpeed:(float)target
                   andMode:(int)mode
{
    if ((self = [super init])) {
        _ID = [NSString stringWithUTF8String:ID];
        _actualSpeed = act;
        _minimumSpeed = min;
        _maximumSpeed = max;
        _safeSpeed = safe;
        _targetSpeed = target;
        _mode = mode == SMC_FAN_MODE_AUTO ? SMCFanModeAuto : SMCFanModeForced;
    }
    
    return self;
}

- (NSString *)description
{
    return SWF(@"<SMCFanInfo %p: current speed: %f, target speed: %f>", self, _actualSpeed, _targetSpeed);
}

@end



#pragma mark - MAIN
/* ********************************************************** */
/* ***************|          MAIN          |***************** */
/* ********************************************************** */

NSString *const __nonnull kSMCWrapperKernelErrorDomain = @"kSMCWrapperKernelErrorDomain";

@implementation SMCWrapper

#pragma mark - Init / dealloc
+ (SMCWrapper *__nullable)wrapper
{
    return [[SMCWrapper alloc] init];
}

- (instancetype)init
{
    if ([SettingsKVStore sharedStore].appIsSandboxed)
        return nil;
    
    if ((self = [super init])) {
        SMCOpen();
    }
    
    return self;
}

- (void)dealloc
{
    SMCClose();
}

#pragma mark - Interface methods
+ (NSInteger)getFanCountWithError:(NSError *_Nullable __autoreleasing *)error
{
    // Open SMC
    SMCWrapper *wrapper = [SMCWrapper wrapper];
    
    int fanCount;
    kern_return_t result = SMCGetTotalFansInSystem(&fanCount);
    
    // Close SMC
    wrapper = nil;
    
    if (result != kIOReturnSuccess) {
        NSDictionary<NSString *, id> *userInfo = @{
            NSLocalizedDescriptionKey: SWF(@"Can't get total fan count from the SMC")
        };
        
        *error = [NSError errorWithDomain:kSMCWrapperKernelErrorDomain code:result userInfo:userInfo];
        
        return -1;
    } else {
        return fanCount;
    }
}

- (SMCCPUInfo *)getCPUInformation
{
    double temp = SMCGetTemperature(SMC_KEY_CPU_TEMP);
    
    return [[SMCCPUInfo alloc] initWithTemp:temp];
}

- (NSArray<SMCFanInfo *> *)getFanInformation
{
    int count;
    SMCFan *fans;
    
    if (SMCGetFanInfo(&count, &fans) != kIOReturnSuccess)
        return nil;
    
    NSMutableArray<SMCFanInfo *> *fanInfos = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        SMCFan fan = fans[i];
        SMCFanInfo *info = [[SMCFanInfo alloc] initWithID:fan.ID
                                              actualSpeed:fan.actual
                                             minimumSpeed:fan.min
                                             maximumSpeed:fan.max
                                                safeSpeed:fan.safe
                                              targetSpeed:fan.target
                                                  andMode:fan.mode];
        
        [fanInfos addObject:info];
    }
    
    return fanInfos;
}

- (SMCPowerInfo *)getPowerInformation
{
    kern_return_t result;
    double val;
    
    result = SMCGetSystemTotalDCIN(&val);
    if (result == kIOReturnSuccess) {
        SMCPowerInfo *info = [[SMCPowerInfo alloc] initWithTotalSystemDCIN:val];
        return info;
    } else {
        return nil;
    }
}

@end
