//
//  FTUploadProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright 2025 Shanghai Guance Information Technology Co., Ltd.
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

#ifndef FTUploadProtocol_h
#define FTUploadProtocol_h

@protocol FTUploadCountProtocol <NSObject>
- (void)uploadLogCount:(NSInteger)count;
- (void)uploadRUMCount:(NSInteger)count;
@end

@protocol FTSessionOnErrorDataHandler <NSObject>
/// Handle Session On Error Datas
- (void)checkRUMSessionOnErrorDatasExpired;
///  Persisted RUM error timeline for session-on-error sampled cache data.
///  This is not the fatal error time from the previous process.
- (long long)getErrorTimeLineFromFileCache;

///  Get the time of fatal error from the previous process
///  -1, not yet obtained
///  0, no FatalError in previous process
///  >0 previous process FatalError time
- (long long)getLastProcessFatalErrorTime;

@end
#endif /* FTUploadProtocol_h */
