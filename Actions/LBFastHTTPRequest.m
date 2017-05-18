//
//  LBFastHTTPRequest.m
//  LBFastHTTPRequest
//
//  Created by Lukas Bischof on 14.01.15.
//  Copyright (c) 2015 Lukas. All rights reserved.
//

#import "LBFastHTTPRequest.h"

@implementation LBFastHTTPRequest

- (void)setMethod:(NSString *)method
{
    _method = method;
    
    if ([method isEqualToString:@"POST"]) {
        if (!_httpHeaderFields && self.httpBody) {
            _httpHeaderFields = @{
                @"Content-Length" : SWF(@"%lu", (unsigned long)[self.httpBody length]),
                @"Current-Type" : @"application/x-www-form-urlencoded"
            };
        }
    }
}

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method httpBody:(NSData *)body andResponse:(LBHTTPRequestResponseHandler)handler
{
    LBFastHTTPRequest *request = [[LBFastHTTPRequest alloc] initWithURL:url];
    request.httpBody = body;
    request.method = [method uppercaseString];
    request.responseHandler = handler;
    [request send];
}

+ (void)sendRequestWithURL:(NSURL *)url httpMethod:(NSString *)method andResponse:(LBHTTPRequestResponseHandler)handler
{
    LBFastHTTPRequest *request = [[LBFastHTTPRequest alloc] initWithURL:url];
    request.method = [method uppercaseString];
    request.responseHandler = handler;
    [request send];
}

+ (void)sendRequestWithURL:(NSURL *)url andResponse:(LBHTTPRequestResponseHandler)handler
{
    [LBFastHTTPRequest sendRequestWithURL:url
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

+ (NSURL *)getURLFromString:(NSString *)string
{
    // Diese Methode ist eigentlich total unnötig, ich verwende sie nur um zu schauen, ob Änderungen übernommen werden (in einem externen Projekt)
    return [NSURL URLWithString:string];
}

+ (NSString *)getClassDescription
{
    return @"Use this class to make HTTP requests fastly :)";
}

@end
