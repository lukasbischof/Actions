//
//  ExecutableFile.m
//  Actions
//
//  Created by Lukas Bischof on 10.06.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import "ExecutableFile.h"
#import <Automator/Automator.h>
#import <Carbon/Carbon.h>
#import "Actions-Swift.h"
#import "NSURL+sandboxing.h"

static inline id getValForKey(NSDictionary *dict, id<NSCoding, NSObject> key, id<NSObject> defaultVal) {
    if ([[dict allKeys] containsObject:key]) {
        id<NSObject> v = [dict objectForKey:key];
        if ([v isKindOfClass:[defaultVal class]])
            return v;
        else
            return defaultVal;
    } else
        return defaultVal;
}

@implementation ExecutableFile {
    NSURL *_url;
}

@synthesize url = ___DONT_USE___; // get-only property


#pragma mark - Init
+ (instancetype)executableFileWithURL:(NSURL *)url
{
    return [[ExecutableFile alloc] initWithURL:url];
}

- (instancetype)init
    __attribute__((noreturn))
    __attribute__((unavailable))
{
    EAbrtLog(@"Can't init an ExecutableFile without a path");
    DEBUG_ONLY(abort()); // Also quit in debug mode
}

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init])) {
        _url = url;
        
        if (!_url)
            return nil;
        
        NSString *extension = _url.pathExtension;
        if ([extension isEqualToString:@"scpt"]) {
            _type = ExecutableFileTypeAppleScript;
        } else if ([extension isEqualToString:@"workflow"]) {
            _type = ExecutableFileTypeAutomatorWorkflow;
        } else if ([extension isEqualToString:@"bundle"] && ![SettingsKVStore sharedStore].appIsSandboxed) {
            _type = ExecutableFileTypeActionBundle;
        } else {
            return nil;
        }
    }
    
    return self;
}

#pragma mark - Main functionality
- (NSError *)runAction
{
    NSError *__block error = nil;
    [[SettingsKVStore sharedStore] accessScriptsURLContentsWithHandler:^(){
        switch (self->_type) {
            case ExecutableFileTypeAppleScript:
                error = [self executeAppleScript];
                break;
                
            case ExecutableFileTypeAutomatorWorkflow:
                error = [self executeAutomatorWorkflow];
                break;
                
            case ExecutableFileTypeActionBundle:
                error = [self executeActionBundle];
                break;
        }
    }];
    
    return error;
}

- (NSError *_Nullable)executeAppleScript
{
    /*
     // Attempt with sandboxing. Doesn't work yet.
    NSError *error;
    NSURL *url = [NSURL fileURLWithPath:@"/Users/Lukas/Library/Application Scripts/de.pf-control.aseider.Actions/sandbox2.scpt"]; //[[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    if (error)
        NSLog(@"error: %@", error);
    
    NSLog(@"url: %@", url);
    
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(ProcessSerialNumber)];
    
    NSAppleEventDescriptor *function = [NSAppleEventDescriptor descriptorWithString:@"run"];
    
    NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite
                                                                             eventID:kASSubroutineEvent
                                                                    targetDescriptor:target
                                                                            returnID:kAutoGenerateReturnID
                                                                       transactionID:kAnyTransactionID];
    [event setParamDescriptor:function forKeyword:keyASSubroutineName];
    
    NSUserAppleScriptTask *appleScriptTask = [[NSUserAppleScriptTask alloc] initWithURL:url error:&error];
    if (error) {
        NSLog(@"error: %@", error);
    }
    
    /// @todo Doesn't work…
    [appleScriptTask executeWithAppleEvent:event completionHandler:^(NSAppleEventDescriptor *_Nullable result, NSError * _Nullable error) {
        NSLog(@"result: %@, error: %@", result, error);
    }];
    
    return nil;*/
    
    NSDictionary *errors;
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:_url
                                                                        error:&errors];
    if (errors && errors.count > 0) {
        NSInteger numb = [(NSNumber *)getValForKey(errors, NSAppleScriptErrorNumber, @-1) integerValue];
        NSString *desc = (NSString *)getValForKey(errors, NSAppleScriptErrorMessage, @"");
        NSError *error = [NSError errorWithDomain:@"NSAppleScriptErrorDomain" code:numb userInfo:@{ NSLocalizedDescriptionKey: desc }];
        return error;
    }
    
    errors = nil;
    [appleScript executeAndReturnError:&errors];
    
    if (errors && errors.count > 0) {
        NSInteger numb = [(NSNumber *)getValForKey(errors, NSAppleScriptErrorNumber, @-1) integerValue];
        NSString *desc = (NSString *)getValForKey(errors, NSAppleScriptErrorMessage, @"");
        NSError *error = [NSError errorWithDomain:@"NSAppleScriptErrorDomain" code:numb userInfo:@{ NSLocalizedDescriptionKey: desc }];
        return error;
    }
    
    return nil;
}

- (NSError *_Nullable)executeAutomatorWorkflow
{
    NSError *error;
    [AMWorkflow runWorkflowAtURL:_url withInput:nil error:&error];
    
    return error;
}

- (NSError *_Nullable)executeActionBundle
{
    /*NSBundle *bundle = [NSBundle bundleWithPath:_path];
    
    if (bundle) {
        NSError *error;
        [bundle loadAndReturnError:&error];
        if (error)
            WLog(@"%@", error);
        DLog(@"Bundle: %@", bundle);
    } else {
        
    }*/
    
    CFErrorRef error;
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, (__bridge CFURLRef)self.url);
    Boolean loaded = CFBundleLoadExecutableAndReturnError(bundle, &error);
    if (loaded) {
        DLog(@"loaded");
    } else {
        WLog(@"didn't load");
    }
    
    CFShow(bundle);
    
    void (*run)(void) = CFBundleGetFunctionPointerForName(bundle, CFSTR("run"));
    if (run)
        run();
    else
        WLog(@"No run method");
    
    CFRelease(bundle);
    
    return nil;
}

#pragma mark - Getters/Setters & Misc
- (NSURL *)url
{
    return _url;
}

- (NSString *)description
{
    return SWF(@"<%@: %p, path: %@>", self.className, self, self.url.absoluteString);
}

@end
