//
//  FTErrorDataProtocol.h
//  FTMobileAgent
//
//  Created by hulilei on 2022/10/12.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#ifndef FTErrorDataProtocol_h
#define FTErrorDataProtocol_h

@protocol FTErrorDataDelegate <NSObject>
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
@end
#endif /* FTErrorDataProtocol_h */
