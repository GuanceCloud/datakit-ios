//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/14.
//  Copyright © 2020 hll. All rights reserved.
//

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTRUMDataWriteProtocol.h"

@class FTPresetProperty,FTTracer;

@interface FTMobileAgent (Private)<FTRUMDataWriteProtocol>
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong , readonly) FTTracer *tracer;

-(void)resetInstance;

@end
#endif /* FTMobileAgent_Private_h */
