// Copyright (c) Microsoft Corporation.  All Rights Reserved.  Licensed under the MIT License.  See License in the project root for license information.



#import <MSGraphCoreSDK/NSDate+MSSerialization.h>

#import "MSGraphModels.h"

@interface MSObject()

@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end

@interface MSGraphSizeRange()
{
    int32_t _minimumSize;
    int32_t _maximumSize;
}
@end

@implementation MSGraphSizeRange

- (int32_t) minimumSize
{
    _minimumSize = [self.dictionary[@"minimumSize"] intValue];
    return _minimumSize;
}

- (void) setMinimumSize: (int32_t) val
{
    _minimumSize = val;
    self.dictionary[@"minimumSize"] = @(val);
}

- (int32_t) maximumSize
{
    _maximumSize = [self.dictionary[@"maximumSize"] intValue];
    return _maximumSize;
}

- (void) setMaximumSize: (int32_t) val
{
    _maximumSize = val;
    self.dictionary[@"maximumSize"] = @(val);
}

@end