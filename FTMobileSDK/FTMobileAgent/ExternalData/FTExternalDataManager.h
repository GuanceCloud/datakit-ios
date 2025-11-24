//
//  FTExternalDataManager.h
//  FTMobileAgent
//
//  Created by hulilei on 2021/11/22.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef enum FTAppState:NSUInteger FTAppState;

@class FTResourceMetricsModel,FTResourceContentModel;

/// Class that implements user custom RUM and Trace functionality
@interface FTExternalDataManager : NSObject

/// Singleton
+ (instancetype)sharedManager;
#pragma mark --------- Rum ----------
/// Create RUM View
///
/// Called before the `-startViewWithName` method, this method is used to record the page loading time. If the loading time cannot be obtained, this method can be omitted.
/// - Parameters:
///   - viewName: RUM View name
///   - loadTime: page loading time
-(void)onCreateView:(NSString *)viewName loadTime:(NSNumber *)loadTime;
/// Starts RUM view
///
/// - Parameters:
///   - viewName: RUM View name
-(void)startViewWithName:(NSString *)viewName;

/// Starts RUM view
/// - Parameters:
///   - viewName: RUM View name
///   - property: event custom properties (optional)
-(void)startViewWithName:(NSString *)viewName property:(nullable NSDictionary *)property;

/// Update view loading time to current RUM view.
/// Must be called between `-startView` and `-stopView` methods to take effect.
/// - Parameters:
///   - duration: loading time duration (nanosecond).
-(void)updateViewLoadingTime:(NSNumber *)duration;

/// Stop RUM View.
-(void)stopView;

/// Stop RUM View.
/// - Parameter property: event custom properties (optional)
-(void)stopViewWithProperty:(nullable NSDictionary *)property;


/// Start RUM Action.
///
/// RUM will bind Resource, Error, and LongTask events that this Action may trigger. Avoid adding multiple times within 0.1s. Only one Action can be associated with the same View at the same time. If the previous Action hasn't ended, new Actions will be discarded.
/// This does not interfere with Actions added by the `addAction:actionType:property` method.
///
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
///   - property: event custom properties (optional)
- (void)startAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;

/// Add Action event. No duration, no discard logic
///
/// This does not interfere with RUM Actions started by `startAction:actionType:property:`.
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
///   - property: event custom properties (optional)
- (void)addAction:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property;
/// Add Error event
///
/// - Parameters:
///   - type: error type
///   - message: error message
///   - stack: stack information
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack;
/// Add Error event
/// - Parameters:
///   - type: error type
///   - message: error message
///   - stack: stack information
///   - property: event custom properties (optional)
- (void)addErrorWithType:(NSString *)type message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// Add Error event
/// - Parameters:
///   - type: error type
///   - state: program running state
///   - message: error message
///   - stack: stack information
///   - property: event custom properties (optional)
- (void)addErrorWithType:(NSString *)type state:(FTAppState)state  message:(NSString *)message stack:(NSString *)stack property:(nullable NSDictionary *)property;

/// Add freeze event
///
/// - Parameters:
///   - stack: freeze stack
///   - duration: freeze duration (nanoseconds)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration;

/// Add freeze event
/// - Parameters:
///   - stack: freeze stack
///   - duration: freeze duration (nanoseconds)
///   - property: event custom properties (optional)
- (void)addLongTaskWithStack:(NSString *)stack duration:(NSNumber *)duration property:(nullable NSDictionary *)property;

/// HTTP request start
///
/// - Parameters:
///   - key: request identifier
- (void)startResourceWithKey:(NSString *)key;
/// HTTP request start
/// - Parameters:
///   - key: request identifier
///   - property: event custom properties (optional)
- (void)startResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

/// HTTP add request data
///
/// - Parameters:
///   - key: request identifier
///   - metrics: request-related performance properties
///   - content: request-related data
- (void)addResourceWithKey:(NSString *)key metrics:(nullable FTResourceMetricsModel *)metrics content:(FTResourceContentModel *)content;
/// HTTP request end
///
/// - Parameters:
///   - key: request identifier
- (void)stopResourceWithKey:(NSString *)key;
/// HTTP request end
/// - Parameters:
///   - key: request identifier
///   - property: event custom properties (optional)
- (void)stopResourceWithKey:(NSString *)key property:(nullable NSDictionary *)property;

#pragma mark --------- Trace ----------
/// Get trace (link tracing) headers that need to be added
/// - Parameters:
///   - url: request URL
- (nullable NSDictionary *)getTraceHeaderWithUrl:(NSURL *)url;
/// When `enableLinkRUMData` is enabled, get trace (link tracing) headers that need to be added
/// - Parameters:
///   - key: request identifier
///   - url: request URL
- (nullable NSDictionary *)getTraceHeaderWithKey:(NSString *)key url:(NSURL *)url;
#pragma mark --------- DEPRECATED ----------

/// Add Click Action event. actionType defaults to `click`
///
/// - Parameters:
///   - actionName: event name
- (void)addClickActionWithName:(NSString *)actionName DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -startAction:actionType:property: method instead");

/// Add Click Action event, actionType defaults to `click`
/// - Parameters:
///   - actionName: event name
///   - property: event custom properties (optional)
- (void)addClickActionWithName:(NSString *)actionName property:(nullable NSDictionary *)property DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -startAction:actionType:property: method instead");

/// Add Action event
///
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -startAction:actionType:property: method instead");
/// Add Action event
/// - Parameters:
///   - actionName: event name
///   - actionType: event type
///   - property: event custom properties (optional)
- (void)addActionName:(NSString *)actionName actionType:(NSString *)actionType property:(nullable NSDictionary *)property DEPRECATED_MSG_ATTRIBUTE("Deprecated, please use -startAction:actionType:property: method instead");
@end

NS_ASSUME_NONNULL_END
