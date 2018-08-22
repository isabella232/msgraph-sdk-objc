// Copyright (c) Microsoft Corporation.  All Rights Reserved.  Licensed under the MIT License.  See License in the project root for license information.

#import "MSURLSessionManager.h"
#import "MSURLSessionTaskDelegate.h"
#import "MSURLSessionTask.h"
#import "MSURLSessionDataTask.h"
#import "MSURLSessionDownloadTask.h"
#import "MSURLSessionUploadTask.h"

@interface MSURLSessionTask()

-(void)setInnerTask:(NSURLSessionTask *)innerTask;

@end

@interface MSURLSessionDownloadTask()

-(NSProgress *)getProgress;

@end

@interface MSURLSessionUploadTask()

@property NSURL *fileURL;

@property NSData *data;

@property BOOL isFileUploadTask;

-(NSProgress *)getProgress;

@end

@interface MSURLSessionManager()

@property (strong, nonatomic) NSURLSessionConfiguration *urlSessionConfiguration;

@property (strong, nonatomic) NSURLSession *urlSession;

@property (strong, nonatomic) NSMutableDictionary *taskDelegates;

@property (nonatomic, strong) id<MSGraphMiddleware> nextMiddleware;

@end

@implementation MSURLSessionManager

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)urlSessionConfiguration
{
    self = [super init];
    if (self){
        _urlSessionConfiguration = urlSessionConfiguration;
        _urlSession = [NSURLSession sessionWithConfiguration:urlSessionConfiguration delegate:self delegateQueue:nil];
        _taskDelegates = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(MSDataCompletionHandler)completionHandler;
{
    NSURLSessionDataTask *dataTask = nil;
    @synchronized(self.urlSession){
        dataTask = [self.urlSession dataTaskWithRequest:request];
    }
    
    [self addDelegateForTask:dataTask withProgress:nil completion:completionHandler];
    return dataTask;
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest:(NSURLRequest *)request progress:(NSProgress * __autoreleasing *)progress completionHandler:(MSRawDownloadCompletionHandler)completionHandler
{
    NSURLSessionDownloadTask *downloadTask = nil;
    @synchronized(self.urlSession){
        downloadTask = [self.urlSession downloadTaskWithRequest:request];
    }
    [self addDelegateForTask:downloadTask withProgress:progress completion:completionHandler];
    
    return downloadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)data
                                         progress:(NSProgress * __autoreleasing *)progress
                                completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    NSURLSessionUploadTask *uploadTask = nil;
    @synchronized(self.urlSession){
        uploadTask = [self.urlSession uploadTaskWithRequest:request fromData:data];
    }
    [self addDelegateForTask:uploadTask withProgress:progress completion:completionHandler];
    
    return uploadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                                         progress:(NSProgress * __autoreleasing *)progress
                                completionHandler:(MSRawUploadCompletionHandler)completionHandler
{
    NSURLSessionUploadTask *uploadTask = nil;
    @synchronized(self.urlSession){
        uploadTask = [self.urlSession uploadTaskWithRequest:request fromFile:fileURL];
    }
    
    [self addDelegateForTask:uploadTask withProgress:progress completion:completionHandler];
    
    return uploadTask;
}

- (void)addDelegateForTask:(NSURLSessionTask *)task
              withProgress:(NSProgress * __autoreleasing *)progress
                completion:(MSURLSessionTaskCompletion)completion
{
    MSURLSessionTaskDelegate *delegate = [[MSURLSessionTaskDelegate alloc]
                                           initWithProgressRef:progress
                                           completion:completion];
    @synchronized(self.taskDelegates){
        self.taskDelegates[@(task.taskIdentifier)] = delegate;
    }
}

- (MSURLSessionTaskDelegate*)getDelegateForTask:(NSURLSessionTask *)task
{
    MSURLSessionTaskDelegate *delegate = nil;
    @synchronized(self.taskDelegates){
        delegate = self.taskDelegates[@(task.taskIdentifier)];
    }
    return delegate;
}

- (void)removeTaskDelegateForTask:(NSURLSessionTask *)task
{
    @synchronized(self.taskDelegates){
        [self.taskDelegates removeObjectForKey:@(task.taskIdentifier)];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    MSURLSessionTaskDelegate *delegate = [self getDelegateForTask:task];
    
    if (delegate){
        [delegate task:task didCompleteWithError:error];
    }
    [self removeTaskDelegateForTask:task];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data
{
    MSURLSessionTaskDelegate *delegate = [self getDelegateForTask:dataTask];
    
    if (delegate){
        [delegate didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didSendBodyData:(int64_t)bytesSent
                                 totalBytesSent:(int64_t)totalBytesSent
                       totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    MSURLSessionTaskDelegate *delegate = [self getDelegateForTask:task];
    
    if (delegate){
        [delegate updateProgressWithBytesSent:totalBytesSent expectedBytes:totalBytesExpectedToSend];
    }
}


- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    MSURLSessionTaskDelegate *delegate = [self getDelegateForTask:downloadTask];
    
    if (delegate){
        [delegate updateProgressWithBytesSent:totalBytesWritten expectedBytes:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    MSURLSessionTaskDelegate *delegate = [self getDelegateForTask:downloadTask];
    
    if (delegate) {
        [delegate task:downloadTask didCompleteDownload:location];
        [delegate task:downloadTask didCompleteWithError:nil];
        // remove the task now so we don't call the completion handler when the completion delegate method gets called
        [self removeTaskDelegateForTask:downloadTask];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)redirectResponse
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSMutableURLRequest *newRequest = nil;
    if (request){
        newRequest = [request mutableCopy];
        [task.originalRequest.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
            [newRequest setValue:value forHTTPHeaderField:key];
        }];
    }
    completionHandler(newRequest);
}

-(void)execute:(MSURLSessionTask *)task withCompletionHandler:(HTTPRequestCompletionHandler)completionHandler{
    if([task isKindOfClass:[MSURLSessionDataTask class]]){
        NSURLSessionTask *dataTask = [self dataTaskWithRequest:task.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSLog(@"exiting middleware http");
            completionHandler(data,response,error);
        }];
        [task setInnerTask:dataTask];
        [dataTask resume];
    }else if([task isKindOfClass:[MSURLSessionDownloadTask class]]){
        NSProgress *progress = [(MSURLSessionDownloadTask *)task getProgress];
        NSURLSessionDownloadTask *downloadTask = [self downloadTaskWithRequest:task.request progress:&progress completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            NSLog(@"exiting middleware http");
            completionHandler(location,response,error);
        }];
        [task setInnerTask:downloadTask];
        [downloadTask resume];

    }
    else if([task isKindOfClass:[MSURLSessionUploadTask class]]){
        NSProgress *progress = [(MSURLSessionUploadTask *)task getProgress];
        NSURLSessionUploadTask *uploadTask;
        if([(MSURLSessionUploadTask *)task isFileUploadTask]){
            uploadTask = [self uploadTaskWithRequest:task.request fromFile:[(MSURLSessionUploadTask *)task fileURL] progress:&progress completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSLog(@"exiting middleware http");
                completionHandler(data,response,error);
            }];
        }
        else{
            uploadTask = [self uploadTaskWithRequest:task.request fromData:[(MSURLSessionUploadTask *)task data] progress:&progress completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSLog(@"exiting middleware http");
                completionHandler(data,response,error);
            }];
        }
        [task setInnerTask:uploadTask];
        [uploadTask resume];

    }
}

-(void)setNext:(id<MSGraphMiddleware>)nextMiddleware{
    id<MSGraphMiddleware> tempMiddleware;
    if(self.nextMiddleware){
        tempMiddleware = self.nextMiddleware;
    }
    _nextMiddleware = nextMiddleware;
    [nextMiddleware setNext:tempMiddleware];
}

@end