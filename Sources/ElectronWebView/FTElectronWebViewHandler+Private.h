//
//  FTElectronWebViewHandler+Private.h
//  GuanceElectronWebView
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import "FTElectronWebViewHandler.h"
#import "FTElectronWebViewDescriptor.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTElectronWebViewHandler ()
- (nullable FTElectronWebViewDescriptor *)descriptorForNativeView:(NSView *)view
                                                            frame:(CGRect)frame;
- (void)consumeFullSnapshotRequestForDescriptor:
    (FTElectronWebViewDescriptor *)descriptor;
@end

NS_ASSUME_NONNULL_END

#endif
