//
//  FTVisitorIDConfig+Private.h
//  FTMobileSDK
//

#import "FTVisitorIDConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface FTVisitorIDConfig ()
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)convertToDictionary;
- (nullable FTVisitorIDConfig *)validatedCopyWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)matchesURL:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
