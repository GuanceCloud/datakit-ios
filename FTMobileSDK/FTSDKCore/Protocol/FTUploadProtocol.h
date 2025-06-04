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
/// 处理 Session On Error Datas
- (void)checkRUMSessionOnErrorDatasExpired;
///  如果文件缓存中无数据则返回 0
- (long long)getErrorTimeLineFromFileCache;

///  获取上一进程致命错误的时间
///  -1,还未获取到
///  0,上一进程无 FatalError
///  >0 上一进程 FatalError 时间
- (long long)getLastProcessFatalErrorTime;

@end
#endif /* FTUploadProtocol_h */
