//
//  FTMessageReceiver.h
//  FTSDKCore
//
//  Created by hulilei on 2024/7/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTMessageReceiver_h
#define FTMessageReceiver_h

@protocol FTMessageReceiver <NSObject>

- (void)receive:(NSString *)key message:(NSDictionary *)message;

@end

#endif /* FTMessageReceiver_h */
