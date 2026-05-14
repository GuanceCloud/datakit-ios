//
//  FTDataFilterManager.h
//  FTMobileSDK
//
//  Created by hulilei on 2026/5/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FTDataFilterManager : NSObject

@property (nonatomic, assign, readonly) BOOL shouldDisableServerFilter;

+ (instancetype)sharedInstance;

- (void)enable:(BOOL)enable
localFilters:(NSDictionary<NSString *, NSArray<NSString *> *> *)localFilters
updateInterval:(int)updateInterval;
- (void)updateRemoteFilterIfNeededWithForce:(BOOL)force;
- (BOOL)isFilteredWithCategory:(NSString *)category
                        source:(NSString *)source
                          uuid:(NSString *)uuid
                          tags:(NSDictionary *)tags
                        fields:(NSDictionary *)fields;
- (void)shutDown;

@end

NS_ASSUME_NONNULL_END
