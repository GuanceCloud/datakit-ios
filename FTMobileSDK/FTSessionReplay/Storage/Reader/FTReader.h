//
//  FTReader.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/26.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTTLV;
@protocol FTReadableFile;

@interface FTBatch : NSObject
@property (nonatomic, strong) NSArray<FTTLV*> *tlvDatas;
@property (nonatomic, strong) id<FTReadableFile> file;
-(instancetype)initWithFile:(id<FTReadableFile>)file datas:(NSArray<FTTLV*> *)datas;
- (NSArray *)events;
- (NSData *)serialize;
@end
@protocol FTReader <NSObject>
- (NSArray<id<FTReadableFile>>*)readFiles:(int)limit;
- (FTBatch*)readBatch:(id<FTReadableFile>)file;
- (void)markBatchAsRead:(FTBatch*)batch;
   
@end

NS_ASSUME_NONNULL_END
