//
//  FTTrackDataManager+Test.h
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2024/12/23.
//  Copyright © 2024 GuanceCloud. All rights reserved.
//

#import "FTTrackDataManager.h"

NS_ASSUME_NONNULL_BEGIN
@class FTDBDataCachePolicy,FTDataUploadWorker;
@interface FTTrackDataManager ()
@property (nonatomic, strong) FTDBDataCachePolicy *dataCachePolicy;
@property (nonatomic, strong) FTDataUploadWorker *dataUploadWorker;

@end

NS_ASSUME_NONNULL_END
