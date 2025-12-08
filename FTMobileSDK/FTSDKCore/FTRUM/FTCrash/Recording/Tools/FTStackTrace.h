//
//  FTStackTrace.h
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTFrame;
@interface FTStackTrace : NSObject
@property (nonatomic, strong) NSArray<FTFrame *> *frames;
-(instancetype)initWithFrames:(NSArray<FTFrame *> *)frames;
@end

NS_ASSUME_NONNULL_END
