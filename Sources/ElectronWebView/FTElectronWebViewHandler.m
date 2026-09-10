//
//  FTElectronWebViewHandler.m
//  GuanceElectronWebView
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import "FTElectronWebViewHandler.h"
#import "FTElectronWebViewHandler+Private.h"
#import "FTElectronWebViewRecorder.h"
#import "FTElectronWebViewTrackingProtocol.h"
#import "FTWKWebViewHandler.h"
#import "FTModuleManager.h"
#import "FTInnerLog.h"
#import "../Core/FTWKWebView/FTWKWebViewHandler+Private.h"
#import "../Core/FTWKWebView/JSBridge/FTWKWebViewJavascriptBridge.h"
#import "../Core/Protocol/FTSRWebTrackingProtocol.h"
#import <objc/runtime.h>
#import <math.h>

NSString *const FTElectronWebViewCommandTakeSubsequentFullSnapshot =
    @"takeSubsequentFullSnapshot";

static const NSUInteger FTElectronBridgeMaximumMessageBytes = 1024 * 1024;
static const CGFloat FTElectronFrameTolerance = 1.0;
static void *FTElectronWebViewDescriptorAssociationKey =
    &FTElectronWebViewDescriptorAssociationKey;

@interface FTWKWebViewHandler (FTElectronWebViewConfiguration)
- (NSDictionary<NSString *, id> *)webViewTraceConfiguration;
@end

@interface FTElectronWebViewHandler () <FTElectronWebViewTrackingProtocol>
@property (nonatomic, strong) NSMutableDictionary<NSNumber *,
    FTElectronWebViewDescriptor *> *descriptors;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, copy, nullable)
    FTElectronWebViewCommandHandler commandHandler;
@property (nonatomic, strong) FTElectronWebViewRecorder *recorder;
@property (nonatomic, assign) int64_t nextStandaloneSlotID;
- (void)clearNativeAssociationForDescriptor:
    (nullable FTElectronWebViewDescriptor *)descriptor;
@end

@implementation FTElectronWebViewHandler

+ (instancetype)sharedInstance {
    static FTElectronWebViewHandler *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _descriptors = [NSMutableDictionary dictionary];
        _lock = [[NSRecursiveLock alloc] init];
        _recorder = [[FTElectronWebViewRecorder alloc] init];
        NSTimeInterval milliseconds = NSDate.date.timeIntervalSince1970 * 1000;
        _nextStandaloneSlotID = (int64_t)milliseconds * 1000;
    }
    return self;
}

- (void)start {
    [[FTModuleManager sharedInstance]
        registerService:@protocol(FTElectronWebViewTrackingProtocol)
               instance:self];
    FTInnerLogInfo(@"[ElectronWebView] bridge started");
}

- (void)startWithCommandHandler:
    (nullable FTElectronWebViewCommandHandler)commandHandler {
    [self.lock lock];
    self.commandHandler = commandHandler;
    [self.lock unlock];
    [self start];
}

- (BOOL)registerWebContentsID:(int64_t)webContentsID
                       slotID:(int64_t)slotID
                     hostView:(NSView *)hostView
                       bounds:(CGRect)bounds
                      visible:(BOOL)visible
                       zIndex:(NSInteger)zIndex {
    if (webContentsID <= 0 || slotID <= 0 || !hostView ||
        ![self isValidBounds:bounds]) {
        FTInnerLogWarning(@"[ElectronWebView] rejected invalid registration "
                          @"webContents=%lld slot=%lld",
                          webContentsID, slotID);
        return NO;
    }

    FTElectronWebViewDescriptor *descriptor =
        [[FTElectronWebViewDescriptor alloc] init];
    descriptor.webContentsID = webContentsID;
    descriptor.slotID = slotID;
    descriptor.standalone = NO;
    descriptor.hostView = hostView;
    descriptor.bounds = bounds;
    descriptor.webContentsVisible = visible;
    descriptor.visible = descriptor.webContentsVisible;
    descriptor.zIndex = zIndex;
    descriptor.bindInfo = [[FTBindInfo alloc] init];

    [self.lock lock];
    FTElectronWebViewDescriptor *previous =
        self.descriptors[@(webContentsID)];
    [self clearNativeAssociationForDescriptor:previous];
    self.descriptors[@(webContentsID)] = descriptor;
    [self.lock unlock];

    FTInnerLogInfo(@"[ElectronWebView] registered webContents=%lld slot=%lld "
                   @"container=%p frame=%@ z=%ld visible=%d",
                   webContentsID, slotID, hostView, NSStringFromRect(bounds),
                   (long)zIndex, descriptor.visible);
    return YES;
}

- (nullable NSNumber *)registerStandaloneWebContentsID:
    (int64_t)webContentsID
                                                 visible:(BOOL)visible {
    if (webContentsID <= 0) {
        FTInnerLogWarning(@"[ElectronWebView] rejected invalid standalone "
                          @"registration webContents=%lld",
                          webContentsID);
        return nil;
    }

    FTElectronWebViewDescriptor *descriptor =
        [[FTElectronWebViewDescriptor alloc] init];
    descriptor.webContentsID = webContentsID;
    descriptor.standalone = YES;
    descriptor.webContentsVisible = visible;
    descriptor.visible = visible;
    descriptor.requiresFullSnapshot = visible;
    descriptor.bindInfo = [[FTBindInfo alloc] init];

    [self.lock lock];
    if (self.nextStandaloneSlotID == INT64_MAX) {
        self.nextStandaloneSlotID = 1;
    } else {
        self.nextStandaloneSlotID += 1;
    }
    descriptor.slotID = self.nextStandaloneSlotID;
    FTElectronWebViewDescriptor *previous =
        self.descriptors[@(webContentsID)];
    [self clearNativeAssociationForDescriptor:previous];
    self.descriptors[@(webContentsID)] = descriptor;
    [self.lock unlock];

    FTInnerLogInfo(@"[ElectronWebView] registered standalone webContents=%lld "
                   @"slot=%lld visible=%d",
                   webContentsID, descriptor.slotID, visible);
    return @(descriptor.slotID);
}

- (BOOL)updateWebContentsID:(int64_t)webContentsID
                     bounds:(CGRect)bounds
                    visible:(BOOL)visible
                     zIndex:(NSInteger)zIndex {
    if (![self isValidBounds:bounds]) {
        return NO;
    }
    [self.lock lock];
    FTElectronWebViewDescriptor *descriptor =
        self.descriptors[@(webContentsID)];
    if (descriptor) {
        BOOL wasVisible = descriptor.visible;
        descriptor.bounds = bounds;
        descriptor.webContentsVisible = visible;
        descriptor.zIndex = zIndex;
        descriptor.visible = descriptor.webContentsVisible;
        // A detached BrowserView can keep its WebContents alive. Do not retain
        // its former Chromium NSView association while it is inactive: Electron
        // may reuse that NSView when a different BrowserView is made visible.
        if (!descriptor.visible) {
            [self clearNativeAssociationForDescriptor:descriptor];
        }
        if (!wasVisible && descriptor.visible) {
            descriptor.requiresFullSnapshot = YES;
        }
    }
    [self.lock unlock];
    return descriptor != nil;
}

- (BOOL)updateStandaloneWebContentsID:(int64_t)webContentsID
                               visible:(BOOL)visible {
    [self.lock lock];
    FTElectronWebViewDescriptor *descriptor =
        self.descriptors[@(webContentsID)];
    if (descriptor && descriptor.isStandalone) {
        BOOL wasVisible = descriptor.visible;
        descriptor.webContentsVisible = visible;
        descriptor.visible = visible;
        if (!wasVisible && visible) {
            descriptor.requiresFullSnapshot = YES;
        }
    } else {
        descriptor = nil;
    }
    [self.lock unlock];
    return descriptor != nil;
}

- (BOOL)receiveMessageQueue:(NSString *)messageQueue
              webContentsID:(int64_t)webContentsID {
    if (![messageQueue isKindOfClass:NSString.class] ||
        messageQueue.length == 0 ||
        [messageQueue lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >
            FTElectronBridgeMaximumMessageBytes) {
        FTInnerLogWarning(@"[ElectronWebView] rejected bridge payload "
                          @"webContents=%lld",
                          webContentsID);
        return NO;
    }

    [self.lock lock];
    FTElectronWebViewDescriptor *descriptor =
        self.descriptors[@(webContentsID)];
    [self.lock unlock];
    if (!descriptor || !descriptor.webContentsVisible) {
        FTInnerLogWarning(@"[ElectronWebView] detached or unregistered sender "
                          @"webContents=%lld",
                          webContentsID);
        return NO;
    }

    NSError *error = nil;
    id decoded = [NSJSONSerialization
        JSONObjectWithData:[messageQueue dataUsingEncoding:NSUTF8StringEncoding]
                   options:NSJSONReadingAllowFragments
                     error:&error];
    if (error || !decoded) {
        FTInnerLogWarning(@"[ElectronWebView] invalid bridge JSON: %@",
                          error.localizedDescription);
        return NO;
    }

    NSArray *messages = [decoded isKindOfClass:NSArray.class]
        ? decoded
        : ([decoded isKindOfClass:NSDictionary.class] ? @[decoded] : nil);
    if (!messages) {
        return NO;
    }

    BOOL handled = NO;
    for (id item in messages) {
        if (![item isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary *message = item;
        if (![message[@"handlerName"] isEqualToString:@"sendEvent"]) {
            continue;
        }
        id data = message[@"data"];
        if (!data || data == NSNull.null) {
            continue;
        }
        [[FTWKWebViewHandler sharedInstance]
            processWebViewBridgeEvent:data
                               slotId:descriptor.slotID
                             bindInfo:descriptor.bindInfo];
        handled = YES;
    }

    if (handled) {
        FTInnerLogDebug(@"[ElectronWebView] received bridge event "
                        @"webContents=%lld slot=%lld",
                        webContentsID, descriptor.slotID);
    }
    return handled;
}

- (void)unregisterWebContentsID:(int64_t)webContentsID {
    [self.lock lock];
    FTElectronWebViewDescriptor *descriptor =
        self.descriptors[@(webContentsID)];
    [self clearNativeAssociationForDescriptor:descriptor];
    [self.descriptors removeObjectForKey:@(webContentsID)];
    [self.lock unlock];
    FTInnerLogInfo(@"[ElectronWebView] unregistered webContents=%lld",
                   webContentsID);
}

- (void)unregisterHostView:(NSView *)hostView {
    if (!hostView) {
        return;
    }
    [self.lock lock];
    NSArray<NSNumber *> *keys = [self.descriptors keysOfEntriesPassingTest:
        ^BOOL(NSNumber *key, FTElectronWebViewDescriptor *descriptor,
              BOOL *stop) {
            return descriptor.hostView == hostView;
        }].allObjects;
    for (NSNumber *key in keys) {
        [self clearNativeAssociationForDescriptor:self.descriptors[key]];
    }
    [self.descriptors removeObjectsForKeys:keys];
    [self.lock unlock];
}

- (void)removeAllRegistrations {
    [self.lock lock];
    for (FTElectronWebViewDescriptor *descriptor in self.descriptors.allValues) {
        [self clearNativeAssociationForDescriptor:descriptor];
    }
    [self.descriptors removeAllObjects];
    [self.lock unlock];
}

- (nullable NSNumber *)slotIDForWebContentsID:(int64_t)webContentsID {
    [self.lock lock];
    FTElectronWebViewDescriptor *descriptor = self.descriptors[@(webContentsID)];
    NSNumber *slotID = descriptor ? @(descriptor.slotID) : nil;
    [self.lock unlock];
    return slotID;
}

- (nullable NSString *)containerViewIDForWebContentsID:(int64_t)webContentsID {
    [self.lock lock];
    NSString *viewID =
        [self.descriptors[@(webContentsID)].bindInfo.viewId copy];
    [self.lock unlock];
    return viewID;
}

- (NSUInteger)registeredWebContentsCount {
    [self.lock lock];
    NSUInteger count = self.descriptors.count;
    [self.lock unlock];
    return count;
}

- (NSUInteger)matchedNativeViewCount {
    [self.lock lock];
    NSUInteger count = 0;
    for (FTElectronWebViewDescriptor *descriptor in self.descriptors.allValues) {
        if (descriptor.matchedNativeView) {
            count += 1;
        }
    }
    [self.lock unlock];
    return count;
}

- (NSDictionary<NSString *, id> *)bridgeConfiguration {
    NSDictionary<NSString *, id> *webViewConfiguration =
        [[FTWKWebViewHandler sharedInstance] webViewTraceConfiguration];
    id<FTSRWebTrackingProtocol> sessionReplay =
        [[FTModuleManager sharedInstance]
            getRegisterService:NSProtocolFromString(@"FTSRWebTrackingProtocol")];
    NSString *privacy = sessionReplay
        ? [sessionReplay getSessionReplayPrivacyLevel]
        : @"mask";
    return @{
        @"enableTraceWebView":
            webViewConfiguration[@"enableTraceWebView"] ?: @NO,
        @"enableWebViewLog":
            webViewConfiguration[@"enableWebViewLog"] ?: @NO,
        @"allowedWebViewHosts":
            webViewConfiguration[@"allowedWebViewHosts"] ?: NSNull.null,
        @"capabilities": sessionReplay ? @"[\"records\"]" : @"[]",
        @"privacyLevel": privacy ?: @"mask",
        @"maximumMessageBytes": @(FTElectronBridgeMaximumMessageBytes),
    };
}

#pragma mark - FTElectronWebViewTrackingProtocol

- (id)sessionReplayRecorder {
    return self.recorder;
}

- (void)takeSubsequentFullSnapshot {
    dispatch_block_t commandBlock = ^{
        [self.lock lock];
        FTElectronWebViewCommandHandler commandHandler =
            [self.commandHandler copy];
        NSArray<FTElectronWebViewDescriptor *> *descriptors =
            [self.descriptors.allValues copy];
        [self.lock unlock];

        if (!commandHandler) {
            return;
        }
        for (FTElectronWebViewDescriptor *descriptor in descriptors) {
            if (descriptor.isStandalone) {
                if (descriptor.visible) {
                    commandHandler(
                        descriptor.webContentsID,
                        FTElectronWebViewCommandTakeSubsequentFullSnapshot
                    );
                }
                continue;
            }
            if (!descriptor.visible || descriptor.hostView.window == nil ||
                ![self isEffectivelyVisible:descriptor.matchedNativeView]) {
                continue;
            }
            commandHandler(
                descriptor.webContentsID,
                FTElectronWebViewCommandTakeSubsequentFullSnapshot
            );
        }
    };
    if (NSThread.isMainThread) {
        commandBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), commandBlock);
    }
}

#pragma mark - Native view reconciliation

- (void)consumeFullSnapshotRequestForDescriptor:
    (FTElectronWebViewDescriptor *)descriptor {
    if (!descriptor) {
        return;
    }

    [self.lock lock];
    [self updateNativeVisibilityForDescriptor:descriptor
                                         view:descriptor.matchedNativeView];
    FTElectronWebViewDescriptor *registered =
        self.descriptors[@(descriptor.webContentsID)];
    BOOL shouldRequest = registered == descriptor &&
        descriptor.visible && descriptor.nativeViewVisible &&
        descriptor.requiresFullSnapshot;
    FTElectronWebViewCommandHandler commandHandler = shouldRequest
        ? [self.commandHandler copy]
        : nil;
    if (commandHandler) {
        descriptor.requiresFullSnapshot = NO;
    }
    [self.lock unlock];

    if (commandHandler) {
        commandHandler(
            descriptor.webContentsID,
            FTElectronWebViewCommandTakeSubsequentFullSnapshot
        );
    }
}

- (nullable FTElectronWebViewDescriptor *)descriptorForNativeView:(NSView *)view
                                                            frame:(CGRect)frame {
    NSAssert(NSThread.isMainThread,
             @"Electron native view reconciliation must run on the main thread.");
    if (!view.window) {
        return nil;
    }

    [self.lock lock];
    if (![self isEffectivelyVisible:view]) {
        FTElectronWebViewDescriptor *hiddenAssociation =
            objc_getAssociatedObject(
                view,
                FTElectronWebViewDescriptorAssociationKey
            );
        [self clearNativeAssociationForDescriptor:hiddenAssociation];
        [self.lock unlock];
        return nil;
    }
    for (FTElectronWebViewDescriptor *descriptor in self.descriptors.allValues) {
        if (descriptor.matchedNativeView &&
            ![self isEffectivelyVisible:descriptor.matchedNativeView]) {
            [self clearNativeAssociationForDescriptor:descriptor];
        }
    }
    FTElectronWebViewDescriptor *associated =
        objc_getAssociatedObject(
            view,
            FTElectronWebViewDescriptorAssociationKey
        );
    if (associated &&
        self.descriptors[@(associated.webContentsID)] == associated &&
        [self descriptor:associated canOwnNativeView:view]) {
        [self updateNativeVisibilityForDescriptor:associated view:view];
        [self.lock unlock];
        return associated;
    }
    if (associated) {
        [self clearNativeAssociationForDescriptor:associated];
    }

    NSArray<FTElectronWebViewDescriptor *> *containerDescriptors =
        [self.descriptors.allValues filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:
                ^BOOL(FTElectronWebViewDescriptor *descriptor,
                      NSDictionary *bindings) {
                    return descriptor.visible &&
                           descriptor.hostView.window == view.window &&
                           [self ancestorDistanceFromView:view
                                              toAncestor:descriptor.hostView] !=
                               NSUIntegerMax;
                }]];

    NSMutableArray<FTElectronWebViewDescriptor *> *nearestDescriptors =
        [NSMutableArray array];
    NSUInteger closestDistance = NSUIntegerMax;
    for (FTElectronWebViewDescriptor *descriptor in containerDescriptors) {
        NSUInteger distance = [self ancestorDistanceFromView:view
                                                     toAncestor:descriptor.hostView];
        if (distance < closestDistance) {
            closestDistance = distance;
            [nearestDescriptors removeAllObjects];
            [nearestDescriptors addObject:descriptor];
        } else if (distance == closestDistance) {
            [nearestDescriptors addObject:descriptor];
        }
    }

    FTElectronWebViewDescriptor *match = nil;
    if (nearestDescriptors.count == 1 &&
        [self descriptor:nearestDescriptors.firstObject
           uniquelyOwnsNativeView:view]) {
        // The preferred path: a Native container controller owns exactly one
        // visible Chromium view. No Electron layout data participates in this
        // identity mapping.
        match = nearestDescriptors.firstObject;
    } else if (nearestDescriptors.count > 0) {
        // A Native container can intentionally contain several visible
        // BrowserViews. Electron has no public NSView handle for an individual
        // WebContents, so use its trusted logical layout only inside this
        // already-known container. Never fall back to matching an NSWindow.
        NSMutableArray<FTElectronWebViewDescriptor *> *frameMatches =
            [NSMutableArray array];
        for (FTElectronWebViewDescriptor *descriptor in nearestDescriptors) {
            if (descriptor.matchedNativeView &&
                descriptor.matchedNativeView != view) {
                continue;
            }
            if ([self frame:descriptor.bounds approximatelyEquals:frame]) {
                [frameMatches addObject:descriptor];
            }
        }

        if (frameMatches.count == 1) {
            match = frameMatches.firstObject;
        } else if (frameMatches.count > 1) {
            NSView *container = frameMatches.firstObject.hostView;
            NSInteger nativeIndex = [self electronViewIndex:view
                                                inContainer:container];
            for (FTElectronWebViewDescriptor *candidate in frameMatches) {
                if (candidate.zIndex == nativeIndex) {
                    match = candidate;
                    break;
                }
            }
        }
    }

    if (match) {
        match.matchedNativeView = view;
        [self updateNativeVisibilityForDescriptor:match view:view];
        objc_setAssociatedObject(
            view,
            FTElectronWebViewDescriptorAssociationKey,
            match,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
    [self.lock unlock];

    if (!match && containerDescriptors.count > 0) {
        FTInnerLogWarning(@"[ElectronWebView] no Electron registration matched "
                          @"native container view=%@ frame=%@",
                          NSStringFromClass(view.class),
                          NSStringFromRect(frame));
    }
    return match;
}

- (void)clearNativeAssociationForDescriptor:
    (FTElectronWebViewDescriptor *)descriptor {
    NSView *view = descriptor.matchedNativeView;
    if (view &&
        objc_getAssociatedObject(
            view,
            FTElectronWebViewDescriptorAssociationKey
        ) == descriptor) {
        objc_setAssociatedObject(
            view,
            FTElectronWebViewDescriptorAssociationKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
    descriptor.matchedNativeView = nil;
    descriptor.nativeViewVisible = NO;
}

- (void)updateNativeVisibilityForDescriptor:
    (FTElectronWebViewDescriptor *)descriptor
                                     view:(NSView *)view {
    BOOL visible = [self isEffectivelyVisible:view];
    if (visible && !descriptor.nativeViewVisible) {
        descriptor.requiresFullSnapshot = YES;
    }
    descriptor.nativeViewVisible = visible;
}

- (BOOL)descriptor:(FTElectronWebViewDescriptor *)descriptor
    canOwnNativeView:(NSView *)view {
    NSView *container = descriptor.hostView;
    return descriptor.visible &&
           container.window == view.window &&
           [self ancestorDistanceFromView:view toAncestor:container] !=
               NSUIntegerMax;
}

- (BOOL)isEffectivelyVisible:(NSView *)view {
    if (!view || !view.window) {
        return NO;
    }
    for (NSView *candidate = view; candidate; candidate = candidate.superview) {
        if (candidate.isHidden || candidate.alphaValue <= 0) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)descriptor:(FTElectronWebViewDescriptor *)descriptor
    uniquelyOwnsNativeView:(NSView *)view {
    return [self descriptor:descriptor canOwnNativeView:view] &&
           [self visibleElectronViewCountInContainer:descriptor.hostView] == 1;
}

- (NSUInteger)ancestorDistanceFromView:(NSView *)view
                             toAncestor:(NSView *)ancestor {
    if (!view || !ancestor) {
        return NSUIntegerMax;
    }
    NSUInteger distance = 0;
    for (NSView *candidate = view; candidate; candidate = candidate.superview) {
        if (candidate == ancestor) {
            return distance;
        }
        distance += 1;
    }
    return NSUIntegerMax;
}

- (NSUInteger)visibleElectronViewCountInContainer:(NSView *)container {
    NSMutableArray<NSView *> *views = [NSMutableArray array];
    [self collectVisibleElectronViews:container output:views];
    return views.count;
}

- (NSInteger)electronViewIndex:(NSView *)target
                    inContainer:(NSView *)container {
    NSMutableArray<NSView *> *views = [NSMutableArray array];
    [self collectVisibleElectronViews:container output:views];
    NSUInteger index = [views indexOfObjectIdenticalTo:target];
    return index == NSNotFound ? NSNotFound : (NSInteger)index;
}

- (void)collectVisibleElectronViews:(NSView *)view
                             output:(NSMutableArray<NSView *> *)output {
    if (!view) {
        return;
    }
    if (view.isHidden) {
        return;
    }
    if ([NSStringFromClass(view.class)
            isEqualToString:@"WebContentsViewCocoa"]) {
        [output addObject:view];
        return;
    }
    for (NSView *subview in view.subviews) {
        [self collectVisibleElectronViews:subview output:output];
    }
}

- (BOOL)isValidBounds:(CGRect)bounds {
    return isfinite(bounds.origin.x) &&
           isfinite(bounds.origin.y) &&
           isfinite(bounds.size.width) &&
           isfinite(bounds.size.height) &&
           bounds.size.width > 0 &&
           bounds.size.height > 0;
}

- (BOOL)frame:(CGRect)left approximatelyEquals:(CGRect)right {
    return fabs(CGRectGetMinX(left) - CGRectGetMinX(right)) <=
               FTElectronFrameTolerance &&
           fabs(CGRectGetMinY(left) - CGRectGetMinY(right)) <=
               FTElectronFrameTolerance &&
           fabs(CGRectGetWidth(left) - CGRectGetWidth(right)) <=
               FTElectronFrameTolerance &&
           fabs(CGRectGetHeight(left) - CGRectGetHeight(right)) <=
               FTElectronFrameTolerance;
}

@end

#endif
