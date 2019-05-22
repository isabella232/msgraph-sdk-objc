//
// Copyright (c) Microsoft Corporation. All Rights Reserved. Licensed under the MIT License. See License in the project root for license information.
//

#import "MSURLSessionTask.h"
#import "MSHTTPClient.h"
#import "MSConstants.h"

@interface MSURLSessionTask()

@property (atomic) BOOL isCancelled;
@property (nonatomic) int featureUsage;

@end

@implementation MSURLSessionTask

- (instancetype)initWithRequest:(NSMutableURLRequest *)request
                         client:(MSHTTPClient *)client
{
    NSParameterAssert(request);
    NSParameterAssert(client);
    
    self = [super init];
    if (self)
    {
        _client = client;
        _request = [request mutableCopy];
    }
    return self;
}

- (void)execute
{
    [self.client.middleware execute:self withCompletionHandler:^(id data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self taskCompletedWithData:data response:response andError:error];
    }];
}

- (void)setRequest:(NSMutableURLRequest *)request
{
    _request = request;
}

- (void)setInnerTask:(NSURLSessionTask *)innerTask
{
    if(_isCancelled)
    {
        [innerTask cancel];
    }else
    {
        _innerTask = innerTask;
    }
}

- (void)cancel
{
    if(_innerTask)
    {
       [_innerTask cancel];

    }else
    {
        _isCancelled = YES;
    }

}

- (void)taskCompletedWithData:(id)data response:(NSURLResponse *)response andError:(NSError *)error
{
    NSAssert(NO, @"Not Implemented, must implement in sub class");
}

- (void)setMiddlewareOptionsArray:(NSArray<MSMiddlewareOptions> *)middlewareOptionsArray
{
    _middlewareOptionsArray = [middlewareOptionsArray copy];
}

- (id<MSMiddlewareOptions>)getMiddlewareOptionWithType:(MSMiddlewareOptionsType)middlewareOptionsType
{
    id<MSMiddlewareOptions> middlewareOptionsToReturn;
    for(id<MSMiddlewareOptions> middlewareOptions in _middlewareOptionsArray)
    {
        if(middlewareOptionsType == middlewareOptions.middlewareOptionsType)
        {
            middlewareOptionsToReturn = middlewareOptions;
            break;
        }
    }
    return middlewareOptionsToReturn;
}

-(void)setFeatureUsage:(int)featureFlag
{
    _featureUsage = _featureUsage | featureFlag;
}

-(NSString *)getFeatureUsage
{
    return [NSString stringWithFormat:@"%X", _featureUsage];
}

@end
