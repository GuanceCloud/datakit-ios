//
//  FTSegmentJSON.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/28.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSegmentJSON : NSObject
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *sessionID;
@property (nonatomic, copy) NSString *viewID;
@property (nonatomic, assign) long long start;
@property (nonatomic, assign) long long end;
@property (nonatomic, strong) NSArray *records;
@property (nonatomic, assign) long long recordsCount;
@property (nonatomic, assign) BOOL hasFullSnapshot;
@property (nonatomic, assign) NSNumber *indexInView;
-(instancetype)initWithData:(NSData *)data;
- (void)mergeAnother:(FTSegmentJSON *)another;
- (NSDictionary *)toJSONODict;
@end

NS_ASSUME_NONNULL_END
