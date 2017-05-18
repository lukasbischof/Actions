//
//  SMCWrapper.h
//  Actions
//
//  Created by Lukas Bischof on 03.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "smc.h"

NS_ASSUME_NONNULL_BEGIN

/* ********************************************************** */
/* **************|         PWR INFO         |**************** */
/* ********************************************************** */

@interface SMCPowerInfo : NSObject

@property (nonatomic, readonly) double totalSystemDC_IN;

@end

/* ********************************************************** */
/* **************|         CPU INFO         |**************** */
/* ********************************************************** */

@interface SMCCPUInfo : NSObject

@property (nonatomic, readonly) double temperature;
@property (nonatomic, readonly) double tempInFarenheit;

@end



/* ********************************************************** */
/* **************|         FAN INFO         |**************** */
/* ********************************************************** */

typedef NS_ENUM(NSUInteger, SMCFanMode) {
    SMCFanModeAuto,
    SMCFanModeForced
};

@interface SMCFanInfo : NSObject

@property (strong, nonatomic, readonly) NSString *ID;
@property (nonatomic, readonly) float actualSpeed;
@property (nonatomic, readonly) float minimumSpeed;
@property (nonatomic, readonly) float maximumSpeed;
@property (nonatomic, readonly) float safeSpeed;
@property (nonatomic, readonly) float targetSpeed;
@property (nonatomic, readonly) SMCFanMode mode;

@end



/* ********************************************************** */
/* *************|          MAIN          |******************* */
/* ********************************************************** */

extern NSString *const __nonnull kSMCWrapperKernelErrorDomain;

@interface SMCWrapper : NSObject

/**
 @method getFanCountWithError:
 @abstract Returns the number of fans installed in the system
 @param error   A pointer to an error object. It get's filled if an error occurred
 @return The fan count or -1 in case of error
*/
+ (NSInteger)getFanCountWithError:(NSError *__autoreleasing *)error;

/**
 @method wrapper
 @abstract Returns an instance of the SMCWrapper class
 @return The SMC object or nil if the wrapper isn't available (i.e. when sandboxing is enabled)
*/
+ (SMCWrapper *_Nullable)wrapper;

/**
 @method init
 @abstract Returns a new instance
 @return The new instance or nil if an error occurred
*/
- (nullable instancetype)init;


/**
 @method getCPUInformation
 @abstract Returns information about the CPU usage
 @return An instance of SMCCPUInfo which contains an array of CPU info for each core
*/
- (SMCCPUInfo *)getCPUInformation;

/**
 @method getFanInformation
 @abstract Returns information about the fans installed
 @return An array of SMCFanInfo objects, one for each fan installed
*/
- (NSArray<SMCFanInfo *> *_Nullable)getFanInformation;

/**
 @method getPowerInformation
 @abstract Returns information about power (usage)
 @return A SMCPowerInfo object, which contains all information about the power (usage)
*/
- (SMCPowerInfo *_Nullable)getPowerInformation;

@end

static inline NSString *NSStringFromSMCFanMode(SMCFanMode mode) {
    switch (mode) {
        case SMCFanModeAuto:
            return @"Auto";
            
        case SMCFanModeForced:
            return @"Forced";
    }
}

NS_ASSUME_NONNULL_END
