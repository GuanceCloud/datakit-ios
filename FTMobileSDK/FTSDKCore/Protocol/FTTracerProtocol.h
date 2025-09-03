//
//  FTTracerProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2022/9/15.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#ifndef FTTracerProtocol_h
#define FTTracerProtocol_h
NS_ASSUME_NONNULL_BEGIN

typedef void(^UnpackTraceHeaderHandler)(NSString * _Nullable traceId, NSString *_Nullable spanID);

/// Trace functionality implementation protocol
@protocol FTTracerProtocol<NSObject>

@property (nonatomic,assign) BOOL enableAutoTrace;

/// Whether to associate with RUM
@property (nonatomic,assign) BOOL enableLinkRumData;

/// Get trace request headers
/// - Parameter url: Request URL
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url;

/// Get trace request headers (for external calls)
/// - Parameters:
///   - url: Request URL
///   - handler: Returns traceID, spanID
- (NSDictionary *)networkTraceHeaderWithUrl:(NSURL *)url handler:(UnpackTraceHeaderHandler)handler;


/// Unpack trace request header parameters
/// - Parameters:
///   - header: Trace request headers
///   - handler: Returns traceID, spanID after unpacking
- (void)unpackTraceHeader:(NSDictionary *)header handler:(UnpackTraceHeaderHandler)handler;
@end
NS_ASSUME_NONNULL_END
#endif /* FTTracerProtocol_h */
