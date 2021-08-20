//
//  FTTrackDataManger.h
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTConstants.h"
/**
 - FTAddDataNormal: trace与rum
 - FTAddDataCache:  logging
 - FTAddDataImmediate: 崩溃日志
 */
typedef NS_ENUM(NSInteger, FTAddDataType) {
    FTAddDataNormal,
    FTAddDataCache,
    FTAddDataImmediate,
};
NS_ASSUME_NONNULL_BEGIN
@class FTRecordModel;
///数据写入，数据上传 相关操作
@interface FTTrackDataManger : NSObject
+(instancetype)sharedInstance;
///数据写入
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type;

///上传数据
- (void)uploadTrackData;
@end

NS_ASSUME_NONNULL_END
