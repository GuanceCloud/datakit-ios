// Reduced third-party fixture. The initializer/global-selection pattern follows
// Tencent TUIChat 8.6.7019; no full IM SDK, server, login or third-party UI is used.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static Class FTProbeDataSourceClass;
static BOOL FTProbeMinimalWasInitialized;
static NSArray<NSString *> *FTProbeMinimalStack;

@protocol FTProbeMessageDataSource <NSObject>
+ (Class)onGetCustomMessageCellDataClass:(NSString *)businessID;
@end

@interface FTProbeDataProvider : NSObject
+ (void)setDataSourceClass:(Class)dataSourceClass;
@end
@implementation FTProbeDataProvider
+ (void)setDataSourceClass:(Class)dataSourceClass {
    FTProbeDataSourceClass = dataSourceClass;
}
@end

@interface FTProbeCustomCellData : NSObject @end
@implementation FTProbeCustomCellData @end

@interface FTProbeClassicController : UIViewController <FTProbeMessageDataSource> @end
@implementation FTProbeClassicController
+ (void)initialize {
    [FTProbeDataProvider setDataSourceClass:self];
}
+ (Class)onGetCustomMessageCellDataClass:(NSString *)businessID {
    return [businessID isEqualToString:@"custom_link"] ? objc_lookUpClass("FTProbeCustomCellData") : Nil;
}
@end

@interface FTProbeMinimalController : UIViewController <FTProbeMessageDataSource> @end
@implementation FTProbeMinimalController
+ (void)initialize {
    FTProbeMinimalWasInitialized = YES;
    FTProbeMinimalStack = [NSThread callStackSymbols];
    [FTProbeDataProvider setDataSourceClass:self];
}
+ (Class)onGetCustomMessageCellDataClass:(NSString *)businessID {
    return Nil; // The custom message is registered only in the classic UI.
}
@end

Class FTProbeSelectedDataSource(void) { return FTProbeDataSourceClass; }
BOOL FTProbeMinimalInitialized(void) { return FTProbeMinimalWasInitialized; }
NSArray<NSString *> *FTProbeInitializationStack(void) { return FTProbeMinimalStack; }
NSString *FTProbeRenderPayload(NSData *payload) {
    NSDictionary *message = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    Class<FTProbeMessageDataSource> dataSource = FTProbeDataSourceClass;
    Class cellDataClass = [dataSource onGetCustomMessageCellDataClass:message[@"businessID"]];
    return cellDataClass != Nil ? @"custom-link-cell" : @"unsupported-message";
}
