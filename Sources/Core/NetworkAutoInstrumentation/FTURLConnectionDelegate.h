//
//  FTURLConnectionDelegate.h
//  FTMobileSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
/// Default observer installed when the application's NSURLConnection delegate is nil.
/// Only observes Resource callbacks; authentication, cache, and body-stream decisions
/// remain with Foundation. These methods also serve as hook observer implementations;
/// they resolve state from the connection and never access delegate ivars.
NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTURLConnectionDelegate : NSObject <NSURLConnectionDataDelegate>

@end
#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
