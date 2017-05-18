//
//  LBFastHTTPRequest.h
//  LBFastHTTPRequest
//
//  Created by Lukas Bischof on 14.01.15.
//  Copyright (c) 2015 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^LBHTTPRequestResponseHandler)(NSData *data, NSHTTPURLResponse *httpResponse);

@interface LBFastHTTPRequest : NSObject

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method andResponse:(LBHTTPRequestResponseHandler)handler;
+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method httpBody:(NSData *)body andResponse:(LBHTTPRequestResponseHandler)handler;
+ (void)sendRequestWithURL:(NSURL *)url andResponse:(LBHTTPRequestResponseHandler)handler;
+ (NSURL *)getURLFromString:(NSString *)string;
+ (NSString *)getClassDescription;


- (instancetype)initWithURL:(NSURL *)url;
- (void)send;

@property (strong, nonatomic) NSString *method;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSData *httpBody;
@property (strong, nonatomic) NSDictionary *httpHeaderFields;
@property (strong, nonatomic) LBHTTPRequestResponseHandler responseHandler;

@end
