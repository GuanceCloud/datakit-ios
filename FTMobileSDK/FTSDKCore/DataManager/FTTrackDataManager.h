//
//  FTTrackDataManager.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
/// 数据添加类型
typedef NS_ENUM(NSInteger, FTAddDataType) {
    ///rum
    FTAddDataNormal,
    ///logging
    FTAddDataLogging,
    ///崩溃日志
    FTAddDataImmediate,
};
NS_ASSUME_NONNULL_BEGIN
@class FTRecordModel;
/// 数据写入，数据上传 相关操作
@interface FTTrackDataManager : NSObject
/// 单例
+(instancetype)sharedInstance;

+(instancetype)startWithAutoSync:(BOOL)autoSync syncPageSize:(int)syncPageSize syncSleepTime:(int)syncSleepTime;

- (void)setLogCacheLimitCount:(int)count logDiscardNew:(BOOL)discardNew;

/// 数据写入
/// - Parameters:
///   - data: 数据
///   - type: 数据存储类型
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type;

/// 上传数据
- (void)uploadTrackData;

/// 关闭单例
- (void)shutDown;

/// 缓存中的数据添加到数据库中
-(void)insertCacheToDB;
@end

NS_ASSUME_NONNULL_END
