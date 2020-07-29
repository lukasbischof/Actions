//
//  FastHTTPRequest.m
//  FastHTTPRequest
//
//  Created by Lukas Bischof on 14.01.15.
//  Copyright (c) 2015 Lukas. All rights reserved.
//

#import "FastHTTPRequest.h"

@implementation FastHTTPRequest

- (void)setMethod:(NSString *)method
{
    _method = method;
    
    // TODO: It does not really make sense that POST requests are automatically of type x-www-form-urlencoded
    if ([method isEqualToString:@"POST"]) {
        if (!_httpHeaderFields && self.httpBody) {
            _httpHeaderFields = @{
                @"Content-Length" : SWF(@"%lu", (unsigned long)[self.httpBody length]),
                @"Current-Type" : @"application/x-www-form-urlencoded"
            };
        }
    }
}

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method httpBody:(NSData *)body andResponse:(HTTPRequestResponseHandler)handler
{
    FastHTTPRequest *request = [[FastHTTPRequest alloc] initWithURL:url];
    request.httpBody = body;
    request.method = [method uppercaseString];
    request.responseHandler = handler;
    [request send];
}

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method andResponse:(HTTPRequestResponseHandler)handler
{
    FastHTTPRequest *request = [[FastHTTPRequest alloc] initWithURL:url];
    request.method = [method uppercaseString];
    request.responseHandler = handler;
    [request send];
}

+ (void)sendRequestWithURL:(NSURL *)url andResponse:(HTTPRequestResponseHandler)handler
{
    [FastHTTPRequest sendRequestWithURL:url
                               httpMethod:@"GET"
                              andResponse:handler];
}

- (instancetype)initWithURL:(NSURL *)url
{
    if ((self = [super init])) {
        self.url = url;
        self.method = @"GET";
    }
    
    return self;
}

- (void)send
{
    if (!self.responseHandler) {
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.url];
    [urlRequest setHTTPMethod:self.method];
    
    if (self.httpHeaderFields) {
        for (id key in [self.httpHeaderFields allKeys]) {
            [urlRequest setValue:self.httpHeaderFields[key] forHTTPHeaderField:[NSString stringWithFormat:@"%@", key]];
        }
    }
    
    if (self.httpBody) {
        [urlRequest setHTTPBody:self.httpBody];
    }
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        if (connectionError) {
            ELog(@"LOADING ERROR: %@", connectionError);
            self.responseHandler(nil, nil);
        }
        
        self.responseHandler(data, (NSHTTPURLResponse *)response);
    }];
}

@end
