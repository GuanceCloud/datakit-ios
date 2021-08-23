//
//  FTSessionConfiguration+Test.m
//  FTMobileSDKUnitTests
//
//  Created by 胡蕾蕾 on 2020/9/7.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTSessionConfiguration+Test.h"
#import <FTURLProtocol.h>
@implementation FTSessionConfiguration (Test)
- (NSArray *)protocolClasses {
  return @[[FTURLProtocol class],NSClassFromString(@"OHHTTPStubsProtocol")];
}
@end
