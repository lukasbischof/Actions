//
//  ExecutableFile.h
//  Actions
//
//  Created by Lukas Bischof on 10.06.16.
//  Copyright © 2016 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>

enum _ExecutableFileType {
    ExecutableFileTypeAppleScript = 0,
    ExecutableFileTypeAutomatorWorkflow,
    ExecutableFileTypeActionBundle // Not in sandboxed mode
};
typedef enum _ExecutableFileType ExecutableFileType;

@interface ExecutableFile : NSObject

@property (assign, nonatomic, readonly) ExecutableFileType type;
@property (DYNAMIC_PROPERTY) NSURL *url;

+ (nullable instancetype)executableFileWithURL:(NSURL *_Nonnull)url;

/// Don't use the standard init method
- (nullable instancetype)init NO_RETURN NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithURL:(NSURL *_Nonnull)url NS_DESIGNATED_INITIALIZER;
- (NSError *_Nullable)runAction;

@end
