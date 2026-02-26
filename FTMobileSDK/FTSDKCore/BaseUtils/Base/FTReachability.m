//
//  FTReachability.m
//  FTMacOSSDK
//
//  Created by hulilei on 2021/8/4.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTReachability.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <Network/Network.h>
#import "FTSDKCompat.h"


@interface FTReachability ()
@property (nonatomic, copy) NSString *net;
@property (nonatomic, assign) SCNetworkReachabilityRef  reachabilityRef;
@property (nonatomic, strong) dispatch_queue_t          reachabilitySerialQueue;
@property (nonatomic, strong) id                        reachabilityObject;
@property (atomic, assign) FTNetworkStatus reachabilityStatus;


-(void)reachabilityChanged:(SCNetworkReachabilityFlags)flags;

@end


static void FTReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target)

    FTReachability *reachability = ((__bridge FTReachability*)info);

    // We probably don't need an autoreleasepool here, as GCD docs state each queue has its own autorelease pool,
    // but what the heck eh?
    @autoreleasepool
    {
        [reachability reachabilityChanged:flags];
    }
}
@implementation FTReachability

+(instancetype)reachabilityWithAddress:(void *)hostAddress{
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
    if (ref)
    {
        id reachability = [[self alloc] initWithReachabilityRef:ref];
        CFRelease(ref);
        return reachability;
    }
    
    return nil;
}

+(instancetype)reachabilityForInternetConnection
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress:&zeroAddress];
}
-(instancetype)initWithReachabilityRef:(SCNetworkReachabilityRef)ref
{
    self = [super init];
    if (self){
        if (ref != NULL) {
            _reachabilityRef = CFRetain(ref);
        }
    }
    return self;
}
-(BOOL)startNotifier{
    if(self.reachabilityObject && (self.reachabilityObject == self))
    {
        return YES;
    }
    _reachabilitySerialQueue = dispatch_queue_create("com.ft.reachability", NULL);
    self.reachabilityStatus = [self currentReachabilityStatus];

    SCNetworkReachabilityContext    context = { 0, NULL, NULL, NULL, NULL };
    context.info = (__bridge void *)self;

    if(SCNetworkReachabilitySetCallback(self.reachabilityRef, FTReachabilityCallback, &context))
    {
        // Set it as our reachability queue, which will retain the queue
        if(SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.reachabilitySerialQueue))
        {
            // this should do a retain on ourself, so as long as we're in notifier mode we shouldn't disappear out from under ourselves
            // woah
            self.reachabilityObject = self;
            return YES;
        }
        else
        {
            // UH OH - FAILURE - stop any callbacks!
            SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
        }
    }

    // if we get here we fail at the internet
    self.reachabilityObject = nil;
    return NO;
}
- (void)stopNotifier
{
    if (_reachabilityRef != NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}
- (FTNetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return FTNetworkStatusNotReachable;
    }

    FTNetworkStatus returnValue = FTNetworkStatusNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = FTNetworkStatusWiFi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = FTNetworkStatusWiFi;
        }
    }

#if !TARGET_OS_OSX
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = FTNetworkStatusWWAN;
    }
#endif
    return returnValue;
}
-(FTNetworkStatus)currentReachabilityStatus{
    FTNetworkStatus returnValue = FTNetworkStatusNotReachable;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
    {
        returnValue = [self networkStatusForFlags:flags];
    }
    
    return returnValue;
}
- (BOOL)connectionRequired{
    NSAssert(_reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
    SCNetworkReachabilityFlags flags;

    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
    {
        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }

    return NO;
}
-(void)reachabilityChanged:(SCNetworkReachabilityFlags)flags{
    FTNetworkStatus status = [self networkStatusForFlags:flags];
    self.reachabilityStatus = status;
    if (self.networkChanged) {
        self.networkChanged(status);
    }
}
- (BOOL)isReachable {
    return [self isReachableViaWWAN] || [self isReachableViaWiFi];
}
-(BOOL)isReachableViaWiFi{
    return self.reachabilityStatus == FTNetworkStatusWiFi;
}
-(BOOL)isReachableViaWWAN{
    return self.reachabilityStatus == FTNetworkStatusWWAN;
}
- (void)dealloc{
    [self stopNotifier];
    if (_reachabilityRef != NULL){
        CFRelease(_reachabilityRef);
    }
}
@end
