//
//  FTExternalResourceManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FTResourceContentModel;
NS_ASSUME_NONNULL_BEGIN
@protocol FTExternalTracing <NSObject>

- (NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;
- (void)traceWithKey:(NSString *)key contentModel:(FTResourceContentModel *)model;
@end
@protocol FTExternalRum <NSObject>
- (void)startResourceWithKey:(NSString *)key;
- (void)stopResourceWithKey:(NSString *)key contentModel:(FTResourceContentModel *)model;
@end
@interface FTExternalResourceManager : NSObject<FTExternalTracing,FTExternalRum>
+ (instancetype)sharedManager;

@end

NS_ASSUME_NONNULL_END
