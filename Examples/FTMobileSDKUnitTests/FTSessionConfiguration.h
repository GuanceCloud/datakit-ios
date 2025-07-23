//
//  FTSessionConfiguration.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/4/21.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTSessionConfiguration : NSObject
//Whether to exchange methods
@property (nonatomic,assign) BOOL isExchanged;

+ (FTSessionConfiguration *)defaultConfiguration;
// Exchange NSURLSessionConfiguration's protocolClasses method
- (void)load;
// Restore initialization
- (void)unload;
@end

NS_ASSUME_NONNULL_END
