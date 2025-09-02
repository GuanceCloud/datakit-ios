//
//  FTSegmentJSON.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/28.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTSegmentJSON.h"
#import "FTConstants.h"
@implementation FTSegmentJSON
-(instancetype)initWithData:(NSData *)data{
    self = [super init];
    if(self){
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        _appId = dict[@"applicationID"];
        _sessionID = dict[@"sessionID"];
        _viewID = dict[@"viewID"];
        _start = LONG_MAX;
        _end = LONG_MIN;
        _source = @"ios";
        NSArray *array = dict[@"records"];
        for (NSDictionary *record in array) {
            NSInteger type = [record[@"type"] integerValue];
            if (type == 2 || type == 10){
                _hasFullSnapshot = YES;
            }
            long long startTimestamp = [record[@"timestamp"] longLongValue];
            long long endTimestamp = [record[@"timestamp"] longLongValue];
            _start = MIN(_start, startTimestamp);
            _end = MAX(_end, endTimestamp);
        }
        _recordsCount = array.count;
        _records = array;
    }
    return self;
}
- (void)mergeAnother:(FTSegmentJSON *)another{
    NSMutableArray *records = [NSMutableArray arrayWithArray:_records];
    [records addObjectsFromArray:another.records];
    self.records = records;
    _start = MIN(_start, another.start);
    _end = MAX(_end, another.end);
    _recordsCount = _recordsCount + another.recordsCount;
    _hasFullSnapshot = _hasFullSnapshot || another.hasFullSnapshot;
}
+(FTJSONKeyMapper *)keyMapper{
    FTJSONKeyMapper *keyMapper = [[FTJSONKeyMapper alloc]initWithModelToJSONDictionary:@{
        @"hasFullSnapshot":@"has_full_snapshot",
        @"recordsCount":@"records_count",
        @"sessionID":FT_RUM_KEY_SESSION_ID,
        @"viewID":FT_KEY_VIEW_ID,
        @"appId":FT_APP_ID,
    }];
    return keyMapper;
}
@end
