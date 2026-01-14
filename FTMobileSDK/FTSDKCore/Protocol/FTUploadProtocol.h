//
//  FTUploadProtocol.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/4/30.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
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
///  If there is no data in file cache, return 0
- (long long)getErrorTimeLineFromFileCache;


@end
#endif /* FTUploadProtocol_h */
