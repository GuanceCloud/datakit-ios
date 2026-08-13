//
//  FTElectronWebViewRecorder.h
//  GuanceElectronWebView
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTElectronWebViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

NS_ASSUME_NONNULL_END

#endif
