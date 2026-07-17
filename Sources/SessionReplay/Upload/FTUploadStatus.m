//
//  FTUploadStatus.m
//  SessionReplay
//
//  Created by hulilei on 2026/5/26.
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FTUploadStatus.h"

@interface FTUploadStatus ()
@property (nonatomic, assign, readwrite) BOOL success;
@property (nonatomic, assign, readwrite) BOOL needsRetry;
@property (nonatomic, strong, readwrite, nullable) NSNumber *responseCode;
@property (nonatomic, strong, readwrite, nullable) NSError *error;
@property (nonatomic, assign, readwrite) NSUInteger attempt;
@property (nonatomic, copy) NSString *uploadDebugDescription;
@end

@implementation FTUploadStatus

+ (instancetype)statusWithHTTPResponse:(nullable NSHTTPURLResponse *)httpResponse
                                 error:(nullable NSError *)error
                        previousStatus:(nullable FTUploadStatus *)previousStatus{
    FTUploadStatus *status = [[FTUploadStatus alloc] init];
    status.attempt = previousStatus ? previousStatus.attempt + 1 : 0;
    status.error = error;
    BOOL hasHTTPResponse = [httpResponse isKindOfClass:[NSHTTPURLResponse class]];
    
    if (hasHTTPResponse) {
        status.responseCode = @(httpResponse.statusCode);
    }
    
    if (error || !hasHTTPResponse) {
        status.success = NO;
        status.needsRetry = YES;
        NSString *errorDescription = error ? error.description : @"Unknown error";
        if (status.responseCode) {
            status.uploadDebugDescription = [NSString stringWithFormat:@"[response code: %@, error: %@, attempt: %lu]", status.responseCode, errorDescription, (unsigned long)status.attempt];
        }else{
            status.uploadDebugDescription = [NSString stringWithFormat:@"[error: %@, attempt: %lu]", errorDescription, (unsigned long)status.attempt];
        }
        return status;
    }
    
    NSInteger statusCode = httpResponse.statusCode;
    status.success = (statusCode >= 200 && statusCode < 500 && statusCode != 403 && statusCode != 429);
    status.needsRetry = !status.success;
    status.uploadDebugDescription = [NSString stringWithFormat:@"[response code: %ld, attempt: %lu]", (long)statusCode, (unsigned long)status.attempt];
    return status;
}

- (NSString *)debugDescription{
    return self.uploadDebugDescription ?: [super debugDescription];
}

- (NSString *)description{
    return self.debugDescription;
}

@end

#endif
