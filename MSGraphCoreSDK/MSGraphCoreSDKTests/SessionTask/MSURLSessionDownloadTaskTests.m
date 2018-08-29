//
//  MSURLSessionDownloadTaskTests.m
//  MSGraphSDK
//
//  Created by canviz on 5/31/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSGraphCoreSDKTests.h"

@interface MSURLSessionDownloadTask()

-(NSProgress *)createProgress;
-(void)taskCompletedWithData:(id)data response:(NSURLResponse *)response andError:(NSError *)error;

@end

@interface MSURLSessionDownloadTaskTests : MSGraphCoreSDKTests
@property (nonatomic) __block BOOL bCompletionBlockInvoked;
@property (nonatomic,retain) NSURL *fileLocation;
@end

@implementation MSURLSessionDownloadTaskTests

- (void)setUp {
    [super setUp];
    self.fileLocation = [NSURL URLWithString:@"foo/bar/baz"];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)testMSURLSessionDownloadTaskInit{
    XCTAssertThrows([[MSURLSessionDownloadTask alloc] initWithRequest:nil client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
    }]);
    XCTAssertThrows([[MSURLSessionDownloadTask alloc] initWithRequest:self.requestForMock client:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
    }]);
    
    MSURLSessionDownloadTask *downloadTask = [[MSURLSessionDownloadTask alloc] initWithRequest:self.requestForMock client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
    }];
    XCTAssertNotNil(downloadTask);
}

-(void)testCreateProgress{
    MSURLSessionDownloadTask *downloadTask = [[MSURLSessionDownloadTask alloc] initWithRequest:self.requestForMock client:self.mockClient completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
    }];
    NSProgress *progress = [downloadTask createProgress];

    XCTAssertEqual(progress, downloadTask.progress);

}

-(void)testDownloadTaskCompletion{
    MSDownloadCompletionHandler requestCompletion = ^(NSURL *fileURL, NSURLResponse * _Nullable response, NSError * _Nullable error){
        //TODO: Handle bool checking gracefully
        self->_bCompletionBlockInvoked = YES;
        XCTAssertNil(error);
        XCTAssertNotNil(response);
        XCTAssertNotNil(fileURL);
    };

    MSURLSessionDownloadTask *downloadTask = [[MSURLSessionDownloadTask alloc] initWithRequest:self.requestForMock client:self.mockClient completionHandler:requestCompletion];
    id<MSGraphMiddleware> middleware = OCMPartialMock(downloadTask.client.middleware);
    OCMStub([middleware execute:[OCMArg any] withCompletionHandler:[OCMArg any]]).andDo(^(NSInvocation *invocation){

        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:MSGraphBaseURL] statusCode:MSExpectedResponseCodesOK HTTPVersion:@"foo" headerFields:nil];
        [downloadTask taskCompletedWithData:[NSURL URLWithString:@"/foo.tmp"] response:response andError:nil];
    });

    [downloadTask execute];
    XCTAssertTrue(_bCompletionBlockInvoked);

}
@end