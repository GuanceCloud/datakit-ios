//
//  FTDataFilter.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDataFilter : NSObject

- (instancetype)initWithFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)filters;
- (BOOL)isMatchedWithCategory:(NSString *)category
                       source:(NSString *)source
                         tags:(NSDictionary *)tags
                       fields:(NSDictionary *)fields;

@end

NS_ASSUME_NONNULL_END
