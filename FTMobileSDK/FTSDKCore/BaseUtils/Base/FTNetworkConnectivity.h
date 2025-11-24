//
//  FTNetworkConnectivity.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/12/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTNetworkChangeObserver <NSObject>
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription;
@end
@interface FTNetworkConnectivity : NSObject
@property (nonatomic, assign, readonly) BOOL isConnected;
@property (nonatomic, copy, readonly) NSString *networkType;

+ (instancetype)sharedInstance;

- (void)addNetworkObserver:(id<FTNetworkChangeObserver>)observer;

- (void)removeNetworkObserver:(id<FTNetworkChangeObserver>)observer;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
