//
//  FastHTTPRequest.h
//  FastHTTPRequest
//
//  Created by Lukas Bischof on 14.01.15.
//  Copyright (c) 2015 Lukas. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^HTTPRequestResponseHandler)(NSData *data, NSHTTPURLResponse *httpResponse);

@interface FastHTTPRequest : NSObject

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method andResponse:(HTTPRequestResponseHandler)handler;
+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method httpBody:(NSData *)body andResponse:(HTTPRequestResponseHandler)handler;
+ (void)sendRequestWithURL:(NSURL *)url andResponse:(HTTPRequestResponseHandler)handler;

- (instancetype)initWithURL:(NSURL *)url;
- (void)send;

@property (strong, nonatomic) NSString *method;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSData *httpBody;
@property (strong, nonatomic) NSDictionary *httpHeaderFields;
@property (strong, nonatomic) HTTPRequestResponseHandler responseHandler;

@end
