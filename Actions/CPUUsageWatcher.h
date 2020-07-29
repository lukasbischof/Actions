//
//  CPUUsageWatcher.h
//  Actions
//
//  Created by Lukas Bischof on 02.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>


/* ********************************************************** */
/* **************|         CPU CORE         |**************** */
/* ********************************************************** */

/**
 @class CPUCore
 @brief Represents one core of the CPU
*/
@interface CPUCore : NSObject

/**
 @property percent
 @abstract The CPU usage (from 0 to 1)
*/
@property (assign, nonatomic, readonly) float percent;

@property (assign, nonatomic, readonly) float inUse;
@property (assign, nonatomic, readonly) float total;

@end


/* ********************************************************** */
/* ************|       USAGE INFORMATION       |************* */
/* ********************************************************** */

/**
 @class CPUUsageInformation
 @brief Holds the usage information of multiple cores
*/
@interface CPUUsageInformation : NSObject<NSCoding>

@property (strong, atomic, readonly, nonnull) NSArray<CPUCore *> *cores;
@property (assign, nonatomic, readonly) float totalPercentage;

@end


/* ********************************************************** */
/* *************|          MAIN          |******************* */
/* ********************************************************** */

extern NSString *_Nonnull const kCPUUsageWatcherKernelErrorDomain;

@protocol CPUUsageWatcherDelegate;

/**
 @class CPUUsageWatcher
 @brief Holds the main interface for getting CPU related information
*/
@interface CPUUsageWatcher : NSObject

- (nonnull instancetype)initWithUpdateInterval:(NSTimeInterval)updateInterval NS_DESIGNATED_INITIALIZER;
- (void)startWatching;
- (void)stopWatching;

@property (weak, nonatomic, nullable) NSObject<CPUUsageWatcherDelegate> *delegate;
@property (assign, atomic, readwrite) NSTimeInterval updateInterval;
@property (assign, nonatomic, readonly) BOOL isWatching;
@property (assign, nonatomic, readonly) unsigned numberOfKerns;

@end

/**
 @protocol CPUUsageWatcherDelegate
 @brief Provides an asynchronous interface for communicating with a CPUUsageWatcher
*/
@protocol CPUUsageWatcherDelegate<NSObject>

@optional
- (void)cpuUsageWatcher:(CPUUsageWatcher *_Nonnull)watcher didReceiveError:(NSError *_Nonnull)error;
- (void)cpuUsageWatcher:(CPUUsageWatcher *_Nonnull)watcher didUpdateUsageInformation:(CPUUsageInformation *_Nonnull)information;

@end
