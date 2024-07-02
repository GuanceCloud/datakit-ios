//
//  FTDataStoreFileReader.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/1.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FTDataStore.h"
NS_ASSUME_NONNULL_BEGIN
@class FTFile;
@interface FTDataStoreFileReader : NSObject
-(instancetype)initWithFile:(FTFile *)file;
- (void)read:(DataStoreValueResult)callback;
@end

NS_ASSUME_NONNULL_END
