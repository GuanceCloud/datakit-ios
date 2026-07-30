//
//  FTAppKitViewRecorders.h
//  SessionReplay AppKit views
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import <Foundation/Foundation.h>
#import "FTSRNodeWireframesBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTNSViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSTextFieldRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSTextViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSImageViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSButtonRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSSwitchRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSSliderRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSSegmentedControlRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSProgressIndicatorRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSTableHeaderViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

NS_ASSUME_NONNULL_END

#endif
