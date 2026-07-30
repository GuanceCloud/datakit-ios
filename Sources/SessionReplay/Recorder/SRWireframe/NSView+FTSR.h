//
//  NSView+FTSR.h
//  SessionReplay
//

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSView (FTSR)

@property (nonatomic, strong, nullable) NSDictionary *SRNodeID;
@property (nonatomic, strong, nullable) NSDictionary *SRNodeIDs;
@property (nonatomic, assign, readonly) BOOL usesDarkMode;

@end

NS_ASSUME_NONNULL_END

#endif
