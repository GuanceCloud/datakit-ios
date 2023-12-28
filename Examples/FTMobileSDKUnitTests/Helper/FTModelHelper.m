//
//  FTModelHelper.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2022/4/14.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTModelHelper.h"
#import <FTConstants.h>
#import <FTDateUtil.h>
#import <FTEnumConstant.h>
#import "FTMobileSDK.h"
#import "FTJSONUtil.h"
#import "FTBaseInfoHandler.h"
@implementation FTModelHelper
+ (FTRecordModel *)createLogModel{
    return  [FTModelHelper createLogModel:[FTDateUtil currentTimeGMT]];
}
+ (FTRecordModel *)createLogModel:(NSString *)message{
    NSDictionary *filedDict = @{FT_KEY_MESSAGE:message,
    };
    NSDictionary *tagDict = @{FT_KEY_STATUS:FTStatusStringMap[FTStatusInfo]};

    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_LOGGER_SOURCE op:FT_DATA_TYPE_LOGGING tags:tagDict fields:filedDict tm:[FTDateUtil currentTimeNanosecond]];
    return model;
}
+ (FTRecordModel *)createRumModel{
    NSDictionary *field = @{ FT_KEY_ERROR_MESSAGE:@"rum_model_create",
                             FT_KEY_ERROR_STACK:@"rum_model_create",
    };
    NSDictionary *tags = @{
        FT_KEY_ERROR_TYPE:@"ios_crash",
        FT_KEY_ERROR_SOURCE:@"logger",
        FT_KEY_ERROR_SITUATION:AppStateStringMap[FTAppStateRun],
        FT_RUM_KEY_SESSION_ID:[FTBaseInfoHandler randomUUID],
        FT_RUM_KEY_SESSION_TYPE:@"user",
    };
    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_RUM_SOURCE_ERROR op:FT_DATA_TYPE_RUM tags:tags fields:field tm:[FTDateUtil currentTimeNanosecond]];
    return model;
}
+ (FTRecordModel *)createWrongFormatRumModel{
    NSDictionary *tags = @{
        FT_KEY_ERROR_TYPE:@"ios_crash",
        FT_KEY_ERROR_SOURCE:@"logger",
        FT_KEY_ERROR_SITUATION:AppStateStringMap[FTAppStateRun],
        FT_RUM_KEY_SESSION_ID:[FTBaseInfoHandler randomUUID],
        FT_RUM_KEY_SESSION_TYPE:@"user",
    };
    FTRecordModel *model = [[FTRecordModel alloc]initWithSource:FT_RUM_SOURCE_ERROR op:FT_DATA_TYPE_RUM tags:tags fields:nil tm:[FTDateUtil currentTimeNanosecond]];
    return model;
}
+ (void)startView{
    [FTModelHelper startView:nil];
}
+ (void)startViewWithName:(NSString *)name{
    [[FTExternalDataManager sharedManager] onCreateView:name loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:name];
}
+ (void)startView:(NSDictionary *)context{
    NSString *viewName = [NSString stringWithFormat:@"view%@",[FTBaseInfoHandler randomUUID]];
    [[FTExternalDataManager sharedManager] onCreateView:viewName loadTime:@1000000000];
    [[FTExternalDataManager sharedManager] startViewWithName:viewName property:context];
}

+ (void)stopView{
    [[FTExternalDataManager sharedManager] stopView];
}
+ (void)stopView:(NSDictionary *)context{
    [[FTExternalDataManager sharedManager] stopViewWithProperty:context];
}
+ (void)startResource:(NSString *)key{
    [[FTExternalDataManager sharedManager] startResourceWithKey:key];
}
+ (void)stopErrorResource:(NSString *)key{
    FTResourceContentModel *model = [FTResourceContentModel new];
    model.url = [NSURL URLWithString:@"https://www.baidu.com/more/"];
    model.httpStatusCode = 404;
    model.httpMethod = @"GET";
    [[FTExternalDataManager sharedManager] stopResourceWithKey:key];
    [[FTExternalDataManager sharedManager] addResourceWithKey:key metrics:nil content:model];
}
+ (void)addAction{
    [[FTExternalDataManager sharedManager] addClickActionWithName:@"testActionClick" property:nil];
}
+ (void)addActionWithType:(NSString *)type{
    [[FTExternalDataManager sharedManager] addActionName:@"testActionClick2" actionType:type property:nil];
}
+ (void)addActionWithContext:(NSDictionary *)context{
    [[FTExternalDataManager sharedManager] addClickActionWithName:@"testActionWithContext" property:context];
}
+ (void)resolveModelArray:(NSArray *)modelArray callBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop))callBack{
    [modelArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *source = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        NSDictionary *fields = opdata[FT_FIELDS];
        if(callBack){
            callBack(source,tags,fields,stop);
        }
    }];
}
+ (void)resolveModelArray:(NSArray *)modelArray idxCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSUInteger idx))callBack{
    [modelArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *source = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        NSDictionary *fields = opdata[FT_FIELDS];
        if(callBack){
            callBack(source,tags,fields,stop,idx);
        }
    }];
}
+ (void)resolveModelArray:(NSArray *)modelArray modelIdCallBack:(void(^)(NSString *source,NSDictionary *tags,NSDictionary *fields,BOOL *stop,NSString *modelId))callBack{
    [modelArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FTRecordModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = [FTJSONUtil dictionaryWithJsonString:obj.data];
        NSDictionary *opdata = dict[@"opdata"];
        NSString *source = opdata[@"source"];
        NSDictionary *tags = opdata[FT_TAGS];
        NSDictionary *fields = opdata[FT_FIELDS];
        if(callBack){
            callBack(source,tags,fields,stop,obj._id);
        }
    }];
}
@end
