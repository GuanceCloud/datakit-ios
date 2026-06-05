//
//  FTModuleManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *FTMessageKey NS_STRING_ENUM;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRUMContext;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRecordsCountByViewID;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySessionHasReplay;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyWebViewSR;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeyRumError;
FOUNDATION_EXPORT FTMessageKey const FTMessageKeySRSampleRateUpdate;
@protocol FTMessageReceiver;

@interface FTHeatmapIdentifier : NSObject<NSCopying>
@property (nonatomic, copy, readonly) NSString *rawValue;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRawValue:(NSString *)rawValue NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithElementPath:(NSArray<NSString *> *)elementPath
                          viewName:(NSString *)viewName
                   bundleIdentifier:(NSString *)bundleIdentifier;
+ (nullable NSValue *)objectIdentifierForObject:(id)object;
@end

@interface FTHeatmapAttributes : NSObject
@property (nonatomic, copy, readonly) NSString *targetPermanentID;
@property (nonatomic, assign, readonly) long long targetWidth;
@property (nonatomic, assign, readonly) long long targetHeight;
@property (nonatomic, assign, readonly) long long positionX;
@property (nonatomic, assign, readonly) long long positionY;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(FTHeatmapIdentifier *)identifier
                              size:(CGSize)size
                          location:(CGPoint)location NS_DESIGNATED_INITIALIZER;
- (NSDictionary *)heatmapActionDictionary;
@end

@protocol FTHeatmapIdentifierRegistry <NSObject>
- (void)setHeatmapIdentifiers:(NSDictionary<NSValue *, FTHeatmapIdentifier *> *)heatmapIdentifiers;
- (nullable FTHeatmapIdentifier *)heatmapIdentifierForObject:(id)object;
@end

@interface FTModuleManager : NSObject
+ (instancetype)sharedInstance;
- (void)postMessageWithKey:(NSString *)key messageBlock:(nullable NSDictionary * (^)(void))messageBlock;
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message;
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message sync:(BOOL)sync;

/// Add delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver;
/// Remove delegate class that conforms to FTMessageReceiver protocol
/// - Parameter delegate: Delegate class that conforms to FTMessageReceiver protocol
- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver;

- (void)registerService:(Protocol *)service instance:(id)instance;

- (id)getRegisterService:(Protocol *)protocol;
@end

NS_ASSUME_NONNULL_END
