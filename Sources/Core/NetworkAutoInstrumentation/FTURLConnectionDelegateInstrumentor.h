//
//  FTURLConnectionDelegateInstrumentor.h
//  FTMobileSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
/// Hooks a non-nil delegate in place. Missing observations receive defaults on
/// the original class, like URLSession. No ISA change or forwarding proxy is used.
/// Root/proxy/download-only and forwarded-observation delegates are unsupported.
NS_EXTENSION_UNAVAILABLE("NSURLConnection automatic instrumentation is not supported in app extensions.")
@interface FTURLConnectionDelegateInstrumentor : NSObject

+ (BOOL)instrumentDelegate:(id)delegate;

/// Internal observer guard: observe an inherited callback chain only once.
+ (BOOL)shouldObserveDelegate:(id)delegate connection:(NSURLConnection *)connection selector:(SEL)selector;

@end
#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
