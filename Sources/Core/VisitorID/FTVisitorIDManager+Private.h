//
//  FTVisitorIDManager+Private.h
//  FTMobileSDK
//

#import "FTVisitorIDManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FTVisitorIDStorage <NSObject>
- (nullable NSDictionary<NSString *, id> *)readRecord;
- (BOOL)writeRecord:(NSDictionary<NSString *, id> *)record;
- (void)removeRecord;
@end

@protocol FTVisitorIDClock <NSObject>
- (NSDate *)now;
@end

@interface FTVisitorIDManager ()
- (instancetype)initWithStorage:(id<FTVisitorIDStorage>)storage
                           clock:(id<FTVisitorIDClock>)clock NS_DESIGNATED_INITIALIZER;
/// Temporarily associates the request snapshot with an automatically collected Resource.
/// The RUM start entry point consumes this value synchronously before queueing its model.
- (void)bindResourceVisitorID:(nullable NSString *)visitorID forKey:(NSString *)key;
- (nullable NSString *)consumeResourceVisitorIDForKey:(NSString *)key;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
