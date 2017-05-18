//
//  CPUUsageWatcher.m
//  Actions
//
//  Created by Lukas Bischof on 02.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "CPUUsageWatcher.h"

#ifndef SWF
#define SWF(string, ...) [NSString stringWithFormat:string, ##__VA_ARGS__]
#endif

/* ********************************************************** */
/* **************|         CPU CORE         |**************** */
/* ********************************************************** */

@interface CPUCore ()

+ (instancetype)coreWithUsedData:(float)used andTotalData:(float)total;
- (instancetype _Nonnull)initWithUsedData:(float)used andTotalData:(float)total;

@end

@implementation CPUCore

+ (instancetype)coreWithUsedData:(float)used andTotalData:(float)total
{
    return [[CPUCore alloc] initWithUsedData:used andTotalData:total];
}

- (instancetype)initWithUsedData:(float)used andTotalData:(float)total
{
    if ((self = [super init])) {
        _inUse = used;
        _total = total;
        _percent = _inUse / _total;
    }
    
    return self;
}

- (NSString *)description
{
    return SWF(@"<CPUCore %p; percent: %f>", self, _percent);
}

@end


/* ********************************************************** */
/* ************|       USAGE INFORMATION       |************* */
/* ********************************************************** */

@interface CPUUsageInformation ()

- (instancetype _Nonnull)initWithCores:(NSArray<CPUCore *> *_Nonnull)cores;

@end

@implementation CPUUsageInformation

- (instancetype)initWithCores:(NSArray<CPUCore *> *)cores
{
    if ((self = [super init])) {
        _cores = cores;
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super init])) {
        _cores = [aDecoder decodeObjectForKey:@"cores"];
    }
    
    return self;
}

- (instancetype)init __attribute__((noreturn))
{
    NSAssert(FALSE, @"Can't use the standard initializer. Please use a custom one");
    exit(EXIT_FAILURE); // remove warning. This code will never be executed, unless the macro has changed…
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_cores forKey:@"cores"];
}

@end



/* ********************************************************** */
/* *************|          MAIN          |******************* */
/* ********************************************************** */

NSString *const kCPUUsageWatcherKernelErrorDomain = @"kCPUUsageWatcherKernelErrorDomain";

@implementation CPUUsageWatcher {
    @package
    processor_info_array_t cpuInfo, prevCpuInfo;
    mach_msg_type_number_t numCpuInfo, numPrevCpuInfo;
    NSThread *updateThread;
    NSLock *CPUUsageLock;
}

- (instancetype)init
{
    self = [self initWithUpdateInterval:3];
    
    return self;
}

- (instancetype)initWithUpdateInterval:(NSTimeInterval)updateInterval
{
    if ((self = [super init])) {
        int mib[2U] = { CTL_HW, HW_NCPU };
        size_t sizeOfNumCPUs = sizeof(_numberOfKerns);
        int status = sysctl(mib, 2U, &_numberOfKerns, &sizeOfNumCPUs, NULL, 0U);
        if (status)
            _numberOfKerns = 1;
        
        CPUUsageLock = [NSLock new];
        _updateInterval = updateInterval;
    }
    
    return self;
}

- (void)startWatching
{
    updateThread = [[NSThread alloc] initWithTarget:self
                                           selector:@selector(updateInfo)
                                             object:nil];
    updateThread.name = @"CPU Activity Thread";
    
    [updateThread start];
    _isWatching = YES;
}

- (void)stopWatching
{
    if (!updateThread.cancelled) {
        [updateThread cancel];
        _isWatching = NO;
    }
}

- (void)delegateCall:(SEL)selector object1:(id __nullable)object1 object2:(id __nullable)object2
{
    [self delegateCall:selector object1:object1 object2:object2 completionHandler:nil];
}

- (void)delegateCall:(SEL)selector object1:(id __nullable)object1 object2:(id __nullable)object2 completionHandler:(void(^ _Nullable)(BOOL didCall))completionHandler
{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:selector]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                IMP implementation = [self.delegate methodForSelector:selector];
                
                if (object1 && object2) {
                    ((void (*)(id, SEL, ...))implementation)(self.delegate, selector, object1, object2);
                    // equv.:
                    //[self.delegate performSelector:selector withObject:object1 withObject:object2];
                } else if (object2 && !object1) {
                    ((void (*)(id, SEL, ...))implementation)(self.delegate, selector, object2);
                } else if (!object2 && object1) {
                    ((void (*)(id, SEL, ...))implementation)(self.delegate, selector, object1);
                } else {
                    ((void (*)(id, SEL))implementation)(self.delegate, selector);
                }
            });
            
            if (completionHandler)
                completionHandler(YES);
            return;
        }
    }
    
    if (completionHandler)
        completionHandler(NO);
}

- (void)updateInfo
{
    while (![NSThread currentThread].cancelled) {
        natural_t numCPUsU = 0U;
        kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
        
        if (err == KERN_SUCCESS) {
            [CPUUsageLock lock];
            
            NSMutableArray<CPUCore *> *coreInformationArray = [NSMutableArray<CPUCore *> arrayWithCapacity:_numberOfKerns];
            for (unsigned int i = 0U; i < _numberOfKerns; i++) {
                float inUse, total;
                
                if (prevCpuInfo) {
                    inUse = (
                             (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER])   +
                             (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM]) +
                             (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE]   - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE])
                    );
                    total = inUse + (cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] - prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE]);
                } else {
                    inUse = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
                    total = inUse + cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
                }
                
                CPUCore *core = [CPUCore coreWithUsedData:inUse andTotalData:total];
                [coreInformationArray addObject:core];
            }
            
            [CPUUsageLock unlock];
            
            CPUUsageInformation *information = [[CPUUsageInformation alloc] initWithCores:coreInformationArray];
            [self delegateCall:@selector(cpuUsageWatcher:didUpdateUsageInformation:) object1:self object2:information];
            
            if (prevCpuInfo) {
                size_t prevCpuInfoSize = sizeof(integer_t) * numPrevCpuInfo;
                vm_deallocate(mach_task_self(), (vm_address_t)prevCpuInfo, prevCpuInfoSize);
            }
            
            prevCpuInfo = cpuInfo;
            numPrevCpuInfo = numCpuInfo;
            
            cpuInfo = NULL;
            numCpuInfo = 0U;
        } else {
            NSError *error = [NSError errorWithDomain:kCPUUsageWatcherKernelErrorDomain
                                                 code:err
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Can't get processor info" }];
            
            [self delegateCall:@selector(cpuUsageWatcher:didReceiveError:) object1:self object2:error completionHandler:^(BOOL didCall) {
                if (!didCall)
                    NSLog(@"ERROR: %@", error);
            }];
            
            break; // Exit main thread loop
        }
        
        [NSThread sleepForTimeInterval:self.updateInterval];
    }
}

- (void)dealloc
{
    [self stopWatching];
}

@end
