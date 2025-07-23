//
//  FTTrackDataManager.h
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
/// Data addition type
typedef NS_ENUM(NSInteger, FTAddDataType) {
    ///rum
    FTAddDataRUM,
    ///logging
    FTAddDataLogging,
    ///rumCache,
    FTAddDataRUMCache
};
NS_ASSUME_NONNULL_BEGIN
@class FTRecordModel,FTDataWriterWorker,FTHTTPClient;
@protocol FTRUMDataWriteProtocol;
/// Data writing and data uploading related operations
@interface FTTrackDataManager : NSObject

@property (nonatomic, strong) FTHTTPClient *httpClient;

@property (nonatomic, strong) FTDataWriterWorker *dataWriterWorker;

/// Singleton
+(instancetype)sharedInstance;

+(instancetype)startWithAutoSync:(BOOL)autoSync
                    syncPageSize:(int)syncPageSize
                   syncSleepTime:(int)syncSleepTime;
- (void)updateAutoSync:(BOOL)autoSync
          syncPageSize:(int)syncPageSize
         syncSleepTime:(int)syncSleepTime;
- (void)setEnableLimitWithDb:(BOOL)enable size:(long)size discardNew:(BOOL)discardNew;
- (void)setLogCacheLimitCount:(int)count discardNew:(BOOL)discardNew;
- (void)setRUMCacheLimitCount:(int)count discardNew:(BOOL)discardNew;

 /// Data writing
/// - Parameters:
///   - data: data
///   - type: data storage type
- (void)addTrackData:(FTRecordModel *)data type:(FTAddDataType)type;

/// Upload data
- (void)flushSyncData;


/// Add cached data to database
-(void)insertCacheToDB;

/// Shut down singleton
+ (void)shutDown;

@end

NS_ASSUME_NONNULL_END
