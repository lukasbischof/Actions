//
//  NTWRKInfo.m
//  Actions
//
//  Created by Lukas Bischof on 12.05.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "NTWRKInfo.h"
#import <objc/runtime.h>
#import <sys/socket.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/ioctl.h> // I/O control
#import <net/if.h>

/* ************************************ */
/* *            INTERFACES            * */
/* ************************************ */

@interface NTWRKInterface ()

- (nonnull instancetype)initWithName:(NSString *_Nonnull)name andAddress:(NTWRKAddress *)address;

@end

@implementation NTWRKInterface

- (instancetype)initWithName:(NSString *)name andAddress:(NTWRKAddress *)address
{
    if ((self = [super init])) {
        _name = name;
        _address = address;
    }
    
    return self;
}

- (NSString *)description
{
    return SWF(@"<NTWRKInterface %p: %@, %@>", self, self.name, self.address ? (__bridge NSString *)self.address->name : @"not active / no address");
}

- (NSString *)menuItemValue
{
    if (self.address)
        return SWF(@"%@: %@", self.name, (__bridge NSString *)self.address->name);
    else
        return SWF(@"%@: n/a", self.name);
}

@end



/* ************************************ */
/* *            MAIN CLASS            * */
/* ************************************ */

@interface NTWRKInfo () <NSNetServiceBrowserDelegate>

@property (strong, nonatomic) NSNetServiceBrowser *browser;
@property (strong, nonatomic) NSMutableArray<NSNetService *> *temporaryStack;
@property (strong, nonatomic) NSMutableArray<NSNetService *> *temporaryRemoveStack;

@end

@implementation NTWRKInfo

#pragma mark - init
- (instancetype)init
{
    if ((self = [super init])) {
        [self setup];
    }
    
    return self;
}

- (void)setup
{
    NSHost *host = [NSHost currentHost];
    
    _hostName = host.localizedName;
    _addresses = host.addresses;
    _interfaces = [self getInterfaces];
    _activeServices = [NSMutableArray<NSNetService *> array];
    _temporaryStack = [NSMutableArray<NSNetService *> array];
    _temporaryRemoveStack = [NSMutableArray<NSNetService *> array];
}

#pragma mark - Interfaces & I-Addresses
- (NSArray<NTWRKInterface *> *)getInterfaces
{
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("findInterface"), NULL, NULL);
    CFPropertyListRef global = SCDynamicStoreCopyValue(store, CFSTR("State:/Network/Interface"));
    NSArray *items = [(__bridge NSDictionary *)global valueForKey:@"Interfaces"];
    
    NSMutableArray<NTWRKInterface *> *interfaces = [NSMutableArray arrayWithCapacity:items.count];
    for (NSString *interface in items) {
        NTWRKAddress *address = get_iface_address([interface UTF8String]);
        NTWRKInterface *retInterface = [[NTWRKInterface alloc] initWithName:interface andAddress:address];
        
        [interfaces addObject:retInterface];
    }
    
    return interfaces;
}

static NTWRKAddress *get_iface_address(const char *interface) {
    if (!interface)
        return NULL;
    
    int sock;
    uint32_t ip;
    struct ifreq ifr;
    char *val;
    
    /* determine UDN according to MAC address */
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return NULL;
    }
    
    strcpy(ifr.ifr_name, interface);
    ifr.ifr_addr.sa_family = AF_INET;
    
    if (ioctl(sock, SIOCGIFADDR, &ifr) < 0) {
        perror("ioctl");
        close(sock);
        return NULL;
    }
    
    struct sockaddr_in *sockaddr = ((struct sockaddr_in *)&ifr.ifr_addr);
    val = (char *)malloc(16 * sizeof(char));
    ip = sockaddr->sin_addr.s_addr;
    ip = ntohl(ip);
    
    sprintf(val, "%d.%d.%d.%d", (ip >> 24) & 0xFF, (ip >> 16) & 0xFF, (ip >> 8) & 0xFF, ip & 0xFF);
    close(sock);
    
    NTWRKAddress *address = malloc(sizeof(NTWRKAddress));
    address->address = ip;
    address->name = CFStringCreateWithCString(kCFAllocatorDefault, val, kCFStringEncodingUTF8);
    address->ipVersion = NTWRKIPVersionIPv4;
    
    return address;
}

#pragma mark - Bonjour & NSNetServiceBrowserDelegate
- (void)setBonjourDelegate:(id<NTWRKBonjourDelegate>)bonjourDelegate
{
    if (bonjourDelegate != nil) {
        _bonjourDelegate = bonjourDelegate;
        
        [self setupBonjourBrowser];
    } else {
        _bonjourDelegate = (void *)0;
        
        [self tearDownBonjourBrowser];
    }
}

- (void)tearDownBonjourBrowser
{
    if (self.browser) {
        [self.browser stop];
        self.browser = nil;
    }
}

- (void)setupBonjourBrowser
{
    if (!self.browser) {
        self.browser = [[NSNetServiceBrowser alloc] init];
        self.browser.delegate = self;
        
        [self.browser searchForServicesOfType:@"_http._tcp" inDomain:@""];
    }
}

- (void)delegateCall:(SEL)selector objects:(NSObject *__nullable)objects, ...
{
    __block va_list list;
    Method method;
    unsigned int numOfArgs;
    
    method = class_getInstanceMethod([self.bonjourDelegate class], selector);
    numOfArgs = method_getNumberOfArguments(method);
    va_start(list, objects);
    
    NSMutableArray<NSObject *> *args = [NSMutableArray array];
    [args addObject:objects];
    
    // store the dynamic params in an array
    // // (numOfArgs - 3): The total numer of arguments minus the hidden arguments self and _cmd, minus the param we already set
    for (unsigned i = 0; i < numOfArgs - 3; i++) {
        NSObject *obj = va_arg(list, NSObject *);
        [args addObject:obj];
    }
    
    va_end(list);
    
    if (self.bonjourDelegate) {
        if ([self.bonjourDelegate respondsToSelector:selector]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self.bonjourDelegate methodSignatureForSelector:selector]];
                invocation.target = self.bonjourDelegate;
                invocation.selector = selector;
                
                NSInteger i = 2; // argument 0 is used for «self» and argument 1 for _cmd (the selector)
                for (NSObject<NSObject> *arg in args) {
                    [invocation setArgument:(void *)&arg atIndex:i++];
                }
                
                [invocation invoke];
            });
        }
    }
}

- (void)delegateCall:(SEL)selector object1:(id __nullable)object1 object2:(id __nullable)object2 completionHandler:(void(^ _Nullable)(BOOL didCall))completionHandler
{
    if (self.bonjourDelegate) {
        if ([self.bonjourDelegate respondsToSelector:selector]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                IMP implementation = [self.bonjourDelegate methodForSelector:selector];
                
                if (object1 && object2)
                    ((void (*)(id, SEL, ...))implementation)(self.bonjourDelegate, selector, object1, object2);
                else if (object2 && !object1)
                    ((void (*)(id, SEL, ...))implementation)(self.bonjourDelegate, selector, object2);
                else if (!object2 && object1)
                    ((void (*)(id, SEL, ...))implementation)(self.bonjourDelegate, selector, object1);
                else
                    ((void (*)(id, SEL))implementation)(self.bonjourDelegate, selector);
            });
            
            if (completionHandler)
                completionHandler(YES);
            return;
        }
    }
    
    if (completionHandler)
        completionHandler(NO);
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Will search");
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    NSLog(@"Did stop search");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
    [self delegateCall:@selector(networkInfo:cantSearch:) object1:self object2:errorDict completionHandler:nil];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    [self.temporaryStack addObject:service];
    
    if (!moreComing) {
        NSUInteger previousCount = self.activeServices.count;
        [self.activeServices addObjectsFromArray:self.temporaryStack];
        //[self delegateCall:@selector(networkInfo:didFindServices:) object1:self object2:[self.temporaryStack copy] completionHandler:nil];
        [self delegateCall:@selector(networkInfo:didFindServices:previousActiveServicesCount:) objects:self, [self.temporaryStack copy], @(previousCount)];
        [self.temporaryStack removeAllObjects];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    [self.temporaryRemoveStack addObject:service];
    
    if (!moreComing) {
        NSUInteger previousCount = self.activeServices.count;
        [self.activeServices removeObjectsInArray:self.temporaryRemoveStack];
        [self delegateCall:@selector(networkInfo:didRemoveServices:previousActiveServicesCount:) objects:self, [self.temporaryRemoveStack copy], @(previousCount)];
        //[self delegateCall:@selector(networkInfo:didRemoveServices:) object1:self object2:[self.temporaryRemoveStack copy] completionHandler:nil];
        [self.temporaryRemoveStack removeAllObjects];
    }
}

#pragma mark - memory management
- (void)dealloc
{
    [self tearDownBonjourBrowser];
}

@end



/* ************************************* */
/* *             FUNCTIONS             * */
/* ************************************* */

const char *iptostr(in_addr_t addr) {
    char *address = malloc(sizeof(char) * 16);
    in_addr_t ip = ntohl(addr);
    
    sprintf(address, "%d.%d.%d.%d", (ip >> 24) & 0xFF, (ip >> 16) & 0xFF, (ip >> 8) & 0xFF, ip & 0xFF);
    
    return address;
}
