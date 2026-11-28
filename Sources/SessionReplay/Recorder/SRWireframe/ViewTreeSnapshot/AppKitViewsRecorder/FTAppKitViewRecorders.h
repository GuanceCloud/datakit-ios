//
//  FTAppKitViewRecorders.h
//  SessionReplay AppKit views
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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

@interface FTNSDatePickerRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

@interface FTNSTableHeaderViewRecorder : NSObject <FTSRWireframesRecorder>
@property (nonatomic, copy) NSString *identifier;
@end

NS_ASSUME_NONNULL_END

#endif
