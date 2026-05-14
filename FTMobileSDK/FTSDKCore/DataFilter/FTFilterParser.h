//
//  FTFilterParser.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL (^FTDataFilterRuleBlock)(NSDictionary<NSString *, id> *values);

@interface FTFilterParser : NSObject

+ (nullable FTDataFilterRuleBlock)predicateWithRule:(NSString *)rule;

@end

NS_ASSUME_NONNULL_END
