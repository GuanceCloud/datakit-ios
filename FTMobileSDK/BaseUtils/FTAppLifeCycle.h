//
//  FTAppLifeCycle.h
//  FTMacOSSDK-framework
//
//  Created by 胡蕾蕾 on 2021/9/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTAppLifeCycleDelegate <NSObject>
@optional

- (void)applicationWillTerminate;

- (void)applicationDidBecomeActive;

- (void)applicationWillResignActive;

#if TARGET_OS_IOS
- (void)applicationWillEnterForeground;
- (void)applicationDidEnterBackground;
#endif

@end
@interface FTAppLifeCycle : NSObject
+ (instancetype)sharedInstance;
- (void)addAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
