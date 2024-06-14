//
//  FTSRWireframesBuilder.h
//  FTMobileSDK
//
//  Created by hulilei on 2023/8/8.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class FTSRWireframe,FTViewAttributes,FTViewTreeRecordingContext;
@protocol FTSRNodeSemantics,FTSRTextObfuscatingProtocol;

typedef id<FTSRNodeSemantics>_Nullable(^SemanticsOverride)(UIView *  view, FTViewAttributes* attributes);
typedef id<FTSRTextObfuscatingProtocol> _Nullable(^FTTextObfuscator)(FTViewTreeRecordingContext *context);

@protocol FTSRWireframesBuilder <NSObject>
- (FTViewAttributes*)attributes;
- (CGRect)wireframeRect;
- (NSArray<FTSRWireframe *>*)buildWireframes;
@end

@protocol FTSRWireframesRecorder <NSObject>
-(id<FTSRNodeSemantics>)recorder:(UIView *)view attributes:(FTViewAttributes *)attributes context:(FTViewTreeRecordingContext *)context;
@end

@protocol FTSRResource <NSObject>
- (NSString *)calculateIdentifier;
- (NSData *)calculateData;
@end
NS_ASSUME_NONNULL_END
