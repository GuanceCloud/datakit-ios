//
//  FTAppLifeCycle.h
//  FTMacOSSDK-framework
//
//  Created by hulilei on 2021/9/17.
//

#import <Foundation/Foundation.h>
#import "FTSDKCompat.h"
NS_ASSUME_NONNULL_BEGIN
/// APP lifecycle protocol
@protocol FTAppLifeCycleDelegate <NSObject>
@optional
/// App did finish launching
- (void)applicationDidFinishLaunching;
/// App will terminate
- (void)applicationWillTerminate;

/// App becomes active
- (void)applicationDidBecomeActive;

/// App will resign active
- (void)applicationWillResignActive;

#if FT_HAS_UIKIT
/// App will enter foreground
- (void)applicationWillEnterForeground;
/// App enters background
- (void)applicationDidEnterBackground;
#endif

@end
/// App lifecycle monitoring utility
@interface FTAppLifeCycle : NSObject
/// Singleton
+ (instancetype)sharedInstance;
/// Add delegate class that conforms to FTAppLifeCycleDelegate protocol
/// - Parameter delegate: Delegate class that conforms to FTAppLifeCycleDelegate protocol
- (void)addAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;
/// Remove delegate class that conforms to FTAppLifeCycleDelegate protocol
/// - Parameter delegate: Delegate class that conforms to FTAppLifeCycleDelegate protocol
- (void)removeAppLifecycleDelegate:(id<FTAppLifeCycleDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
