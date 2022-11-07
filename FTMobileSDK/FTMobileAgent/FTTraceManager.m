//
//  FTTraceManager.m
//  FTMobileAgent
//
//  Created by hulilei on 2022/11/7.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "FTTraceManager.h"
#import "FTExternalDataManager.h"
@implementation FTTraceManager
+ (instancetype)sharedInstance {
    static FTTraceManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });
    return sharedInstance;
}
- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url{
    return [[FTExternalDataManager sharedManager] getTraceHeaderWithKey:key url:url];
}


@end
