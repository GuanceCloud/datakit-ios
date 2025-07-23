//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by hulilei on 2020/5/14.
//  Copyright © 2020 hll. All rights reserved.
//

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTPresetProperty,FTTracer;

@interface FTMobileAgent (Private)
/// Wait for all data being processed to complete
- (void)syncProcess;
@end
#endif /* FTMobileAgent_Private_h */
