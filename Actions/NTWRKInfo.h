//
//  NTWRKInfo.h
//  Actions
//
//  Created by Lukas Bischof on 12.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "Actions-Swift.h"

/* ************************************ */
/* *            INTERFACES            * */
/* ************************************ */

typedef NS_ENUM(NSInteger, NTWRKIPVersion) {
    NTWRKIPVersionIPv4,
    NTWRKIPVersionIPv6
};

typedef struct {
    uint32_t address;
    NTWRKIPVersion ipVersion;
    CFStringRef _Nonnull name;
} NTWRKAddress;

typedef struct {
    BOOL isLoopback;
    BOOL isUp;
    BOOL isRunning;
} NTWRKIFaceInfo;

@interface NTWRKInterface : NSObject<CustomNetworkingMenuItem>

@property (strong, nonatomic, readonly, nonnull) NSString *name;
@property (assign, nonatomic, readonly) NTWRKAddress *_Nullable address;
@property (assign, nonatomic, readonly) NTWRKIFaceInfo *_Nullable info;

@end


/* ************************************ */
/* *            MAIN CLASS            * */
/* ************************************ */

@protocol NTWRKBonjourDelegate;

@interface NTWRKInfo : NSObject

/**
 @property hostName
 @abstract The name of the current host
*/
@property (strong, nonatomic, readonly, nonnull) NSString *hostName;

/**
 @property addressess
 @abstract All active addresses unordered
*/
@property (strong, nonatomic, readonly, nonnull) NSArray<NSString *> *addresses;

/**
 @property interfaces
 @abstract All network interfaces
*/
@property (strong, nonatomic, readonly, nonnull) NSArray<NTWRKInterface *> *interfaces;

/**
 @property bonjourDelegate
 @abstract The interface for bonjour netservice search callback. The search starts as soon the property gets assigned. 
*/
@property (weak, nonatomic, readwrite, nullable) NSObject<NTWRKBonjourDelegate> *bonjourDelegate;

/**
 @property activeServices
 @abstract All discovered services
*/
@property (strong, nonatomic, readonly, nonnull) NSMutableArray<NSNetService *> *activeServices;

@end

@protocol NTWRKBonjourDelegate<NSObject>

- (void)networkInfo:(NTWRKInfo *_Nonnull)info cantSearch:(NSDictionary<NSString *, NSNumber *> *_Nonnull)errorDict;
- (void)networkInfo:(NTWRKInfo *_Nonnull)info didFindServices:(NSArray<NSNetService *> *_Nonnull)services previousActiveServicesCount:(NSNumber *_Nonnull)count;
- (void)networkInfo:(NTWRKInfo *_Nonnull)info didRemoveServices:(NSArray<NSNetService *> *_Nonnull)services previousActiveServicesCount:(NSNumber *_Nonnull)count;

@end


/* ************************************* */
/* *             FUNCTIONS             * */
/* ************************************* */

extern const char *_Null_unspecified iptostr(in_addr_t addr);

