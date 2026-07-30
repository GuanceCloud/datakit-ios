//
//  FTAppKitSessionReplayTests.m
//  macOS-AppTests
//
//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <WebKit/WebKit.h>
#import "FTFeatureUpload.h"
#import "FTFileWriter.h"
#import "FTHTTPClient.h"
#import "FTPerformancePreset.h"
#import "FTPresetProperty.h"
#import "FTReader.h"
#import "FTResourceCheckRequest.h"
#import "FTResourceProcessor.h"
#import "FTResourceRequest.h"
#import "FTRecordWriter.h"
#import "FTResourcesWriter.h"
#import "FTRumSessionReplay.h"
#import "FTScreenChangeScheduler.h"
#import "FTSegmentJSON.h"
#import "FTSegmentRequest.h"
#import "FTSessionReplayConfig.h"
#import "FTSessionReplayTouches.h"
#import "FTSessionReplayWireframesBuilder.h"
#import "FTSnapshotProcessor.h"
#import "FTSRNodeWireframesBuilder.h"
#import "FTSRRecord.h"
#import "FTSRWireframe.h"
#import "FTTouchSnapshot.h"
#import "FTUploadStatus.h"
#import "FTViewAttributes.h"
#import "FTViewTreeSnapshot.h"
#import "FTViewTreeSnapshotBuilder.h"
#import "FTWindowObserver.h"
#import "NSView+FTSRPrivacy.h"

@interface FTImageFeatureUpload (FTAppKitSessionReplayTesting)
- (FTUploadStatus *)flushWithEvent:(id)event parameters:(NSDictionary *)parameters;
- (void)cancelSynchronously;
@end

@interface FTSessionReplayTouches (FTAppKitSessionReplayTesting)
- (void)recordMouseEventType:(NSEventType)type
                buttonNumber:(NSInteger)buttonNumber
            locationInWindow:(NSPoint)locationInWindow
                      window:(nullable NSWindow *)eventWindow;
@end

@interface FTScreenChangeScheduler (FTAppKitSessionReplayTesting)
@property (nonatomic, strong, readonly, nullable) NSTimer *captureTimer;
@end

@interface FTAppKitResourceCheckHTTPClient : FTHTTPClient
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, strong) NSData *responseData;
@property (nonatomic, assign) NSUInteger checkRequestCount;
@property (nonatomic, assign) NSUInteger writeRequestCount;
@end

@implementation FTAppKitResourceCheckHTTPClient
- (void)sendRequest:(id<FTRequestProtocol>)request
         completion:(void (^)(NSHTTPURLResponse * _Nullable,
                              NSData * _Nullable,
                              NSError * _Nullable))callback {
    if ([request isKindOfClass:FTResourceCheckRequest.class]) {
        self.checkRequestCount += 1;
    } else {
        self.writeRequestCount += 1;
    }
    NSHTTPURLResponse *response =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                   statusCode:self.statusCode
                                  HTTPVersion:nil
                                 headerFields:@{@"Content-Type": @"text/html"}];
    callback(response, self.responseData, nil);
}
@end

@interface FTAppKitNoOpUploadStorage : NSObject <FTReader, FTCacheWriter>
@end

@implementation FTAppKitNoOpUploadStorage
- (NSArray<id<FTReadableFile>> *)readFiles:(int)limit {
    return @[];
}
- (FTBatch *)readBatch:(id<FTReadableFile>)file {
    return nil;
}
- (void)markBatchAsRead:(FTBatch *)batch {
}
- (void)write:(NSData *)datas {
}
- (void)write:(NSData *)datas forceNewFile:(BOOL)update {
}
- (void)active {
}
- (void)inactive {
}
- (void)cleanup {
}
@end

@interface FTAppKitCapturingRecordWriter : FTRecordWriter
@property (nonatomic, strong, nullable) NSData *recordData;
@property (nonatomic, strong, nullable) XCTestExpectation *writeExpectation;
@end

@implementation FTAppKitCapturingRecordWriter
- (instancetype)init {
    return [super init];
}
- (BOOL)isErrorSampled {
    return NO;
}
- (void)write:(NSData *)data forceNewFile:(BOOL)force {
    self.recordData = data;
    [self.writeExpectation fulfill];
}
@end

@interface FTAppKitNoOpResourcesWriter : NSObject <FTResourcesWriting>
@end

@implementation FTAppKitNoOpResourcesWriter
- (void)write:(NSArray<FTEnrichedResource *> *)resources {
}
@end

@interface FTAppKitSessionReplayTests : XCTestCase
@end

@implementation FTAppKitSessionReplayTests

- (void)testMacOSPublicEntryPointLinks {
    FTSessionReplayConfig *config = [FTSessionReplayConfig new];
    config.sampleRate = 0;
    config.sessionReplayOnErrorSampleRate = 0;

    [[FTRumSessionReplay sharedInstance] startWithSessionReplayConfig:config];
}

- (void)testMacOSSessionReplayPresetUsesNativePlatformMetadata {
    FTPresetProperty *presetProperty = [FTPresetProperty new];
    [presetProperty startWithVersion:@"1.0"
                         sdkVersion:@"1.0"
                                env:@"test"
                            service:@"demo-service"
                      globalContext:nil
                            pkgInfo:nil];

    NSDictionary *metadata = presetProperty.sessionReplayTags;
    XCTAssertEqualObjects(metadata[@"source"], @"macos");
    XCTAssertEqualObjects(metadata[@"sdk_name"], @"df_macos_rum_sdk");

    [presetProperty shutDown];
}

- (FTSRContext *)allowContentContext {
    FTSRContext *context = [FTSRContext new];
    context.date = [NSDate date];
    context.textAndInputPrivacy = FTTextAndInputPrivacyLevelMaskSensitiveInputs;
    context.imagePrivacy = FTImagePrivacyLevelMaskNone;
    context.touchPrivacy = FTTouchPrivacyLevelHide;
    return context;
}

- (FTSRContext *)showTouchesContext {
    FTSRContext *context = [self allowContentContext];
    context.touchPrivacy = FTTouchPrivacyLevelShow;
    return context;
}

- (NSArray<FTSRWireframe *> *)wireframesForSnapshot:(FTViewTreeSnapshot *)snapshot {
    FTSessionReplayWireframesBuilder *builder =
        [[FTSessionReplayWireframesBuilder alloc] initWithResources:snapshot.resources
                                                    webViewSlotIDs:snapshot.webViewSlotIDs];
    NSMutableArray<FTSRWireframe *> *wireframes = [NSMutableArray array];
    for (id<FTSRNodeWireframesBuilder> node in snapshot.nodes) {
        [wireframes addObjectsFromArray:[node buildWireframesWithBuilder:builder]];
    }
    return wireframes;
}

- (NSData *)resourceDataForUploadTest {
    FTEnrichedResource *resource = [FTEnrichedResource new];
    resource.identifier = @"resource-a";
    resource.appId = @"app-id";
    resource.data = [@"resource-data" dataUsingEncoding:NSUTF8StringEncoding];
    resource.mimeType = @"image/png";
    resource.bindInfo = @{@"user_id": @"user-1"};
    return [resource toJSONData];
}

- (FTImageFeatureUpload *)imageUploadWithHTTPClient:(FTHTTPClient *)httpClient {
    FTAppKitNoOpUploadStorage *storage = [FTAppKitNoOpUploadStorage new];
    FTImageFeatureUpload *upload =
        [[FTImageFeatureUpload alloc] initWithFeatureName:@"session-replay-resources"
                                              fileReader:storage
                                             cacheWriter:storage
                                          requestBuilder:[FTResourceRequest new]
                                     maxBatchesPerUpload:1
                                             performance:[FTPerformancePreset new]
                                                 context:@{}];
    [upload setValue:httpClient forKey:@"httpClient"];
    [upload cancelSynchronously];
    return upload;
}

- (void)testResourceCheck404HTMLIsNotParsedOrRetried {
    FTAppKitResourceCheckHTTPClient *httpClient = [FTAppKitResourceCheckHTTPClient new];
    httpClient.statusCode = 404;
    httpClient.responseData =
        [@"\n<!doctype html><html><body>Not Found</body></html>"
            dataUsingEncoding:NSUTF8StringEncoding];
    FTImageFeatureUpload *upload = [self imageUploadWithHTTPClient:httpClient];

    FTUploadStatus *status =
        [upload flushWithEvent:@[[self resourceDataForUploadTest]]
                    parameters:@{@"service": @"demo-service"}];

    XCTAssertTrue(status.success);
    XCTAssertFalse(status.needsRetry);
    XCTAssertEqualObjects(status.responseCode, @404);
    XCTAssertEqual(httpClient.checkRequestCount, 1u);
    XCTAssertEqual(httpClient.writeRequestCount, 0u);
}

- (void)testMalformedSuccessfulResourceCheckResponseIsRetried {
    FTAppKitResourceCheckHTTPClient *httpClient = [FTAppKitResourceCheckHTTPClient new];
    httpClient.statusCode = 200;
    httpClient.responseData =
        [@"\n<!doctype html><html><body>Unexpected response</body></html>"
            dataUsingEncoding:NSUTF8StringEncoding];
    FTImageFeatureUpload *upload = [self imageUploadWithHTTPClient:httpClient];

    FTUploadStatus *status =
        [upload flushWithEvent:@[[self resourceDataForUploadTest]]
                    parameters:@{@"service": @"demo-service"}];

    XCTAssertFalse(status.success);
    XCTAssertTrue(status.needsRetry);
    XCTAssertEqualObjects(status.responseCode, @200);
    XCTAssertEqual(httpClient.checkRequestCount, 1u);
    XCTAssertEqual(httpClient.writeRequestCount, 0u);
}

- (void)testWindowObserverCapturesOnlyKeyWindowContentView {
    NSWindow *keyWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 320, 240)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    NSWindow *nonKeyWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 120, 80)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    NSView *keyContentView = keyWindow.contentView;
    NSView *nonKeyContentView = nonKeyWindow.contentView;
    FTWindowObserver *observer = [[FTWindowObserver alloc]
        initWithKeyWindowProvider:^NSWindow * _Nullable{
            return keyWindow;
        }];

    XCTAssertEqualObjects(observer.rootViews, (@[keyContentView]));
    XCTAssertEqual(observer.referenceView, keyContentView);
    XCTAssertFalse([observer.rootViews containsObject:nonKeyContentView]);
}

- (void)testWindowObserverSkipsCaptureWithoutKeyWindow {
    FTWindowObserver *observer = [[FTWindowObserver alloc]
        initWithKeyWindowProvider:^NSWindow * _Nullable{
            return nil;
        }];

    XCTAssertNil(observer.rootViews);
    XCTAssertNil(observer.referenceView);
}

- (void)testAppKitPointerCaptureRecordsClicksWithoutEnablingMouseMovedEvents {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 200, 100)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    FTWindowObserver *observer = [[FTWindowObserver alloc]
        initWithKeyWindowProvider:^NSWindow * _Nullable{
            return window;
        }];
    BOOL acceptsMouseMovedEvents = window.acceptsMouseMovedEvents;
    FTSessionReplayTouches *touches =
        [[FTSessionReplayTouches alloc] initWithWindowObserver:observer];

    [touches recordMouseEventType:NSEventTypeLeftMouseDown
                    buttonNumber:0
                locationInWindow:NSMakePoint(25, 30)
                          window:window];
    [touches recordMouseEventType:NSEventTypeMouseMoved
                    buttonNumber:0
                locationInWindow:NSMakePoint(30, 35)
                          window:window];
    [touches recordMouseEventType:NSEventTypeLeftMouseUp
                    buttonNumber:0
                locationInWindow:NSMakePoint(25, 30)
                          window:window];

    FTTouchSnapshot *snapshot =
        [touches takeTouchSnapshotWithContext:[self showTouchesContext]];

    XCTAssertEqual(window.acceptsMouseMovedEvents, acceptsMouseMovedEvents);
    XCTAssertEqual(snapshot.touches.count, 2u);
    XCTAssertEqual(snapshot.touches[0].phase, TouchDown);
    XCTAssertEqual(snapshot.touches[1].phase, TouchUp);
    XCTAssertEqual(snapshot.touches[0].identifier, snapshot.touches[1].identifier);
    XCTAssertEqualWithAccuracy(snapshot.touches[0].position.x, 25, 0.001);
    XCTAssertEqualWithAccuracy(snapshot.touches[0].position.y, 70, 0.001);
}

- (void)testAppKitPointerCaptureRecordsDragTrajectoryWithStableIdentifier {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 200, 100)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    FTWindowObserver *observer = [[FTWindowObserver alloc]
        initWithKeyWindowProvider:^NSWindow * _Nullable{
            return window;
        }];
    FTSessionReplayTouches *touches =
        [[FTSessionReplayTouches alloc] initWithWindowObserver:observer];

    [touches recordMouseEventType:NSEventTypeLeftMouseDown
                    buttonNumber:0
                locationInWindow:NSMakePoint(10, 20)
                          window:window];
    [touches recordMouseEventType:NSEventTypeLeftMouseDragged
                    buttonNumber:0
                locationInWindow:NSMakePoint(20, 30)
                          window:window];
    [touches recordMouseEventType:NSEventTypeLeftMouseDragged
                    buttonNumber:0
                locationInWindow:NSMakePoint(30, 40)
                          window:window];
    [touches recordMouseEventType:NSEventTypeLeftMouseUp
                    buttonNumber:0
                locationInWindow:NSMakePoint(40, 50)
                          window:window];

    FTTouchSnapshot *snapshot =
        [touches takeTouchSnapshotWithContext:[self showTouchesContext]];

    XCTAssertEqual(snapshot.touches.count, 4u);
    XCTAssertEqual(snapshot.touches[0].phase, TouchDown);
    XCTAssertEqual(snapshot.touches[1].phase, TouchMoved);
    XCTAssertEqual(snapshot.touches[2].phase, TouchMoved);
    XCTAssertEqual(snapshot.touches[3].phase, TouchUp);
    int pointerID = snapshot.touches.firstObject.identifier;
    for (FTTouchCircle *touch in snapshot.touches) {
        XCTAssertEqual(touch.identifier, pointerID);
    }
    XCTAssertEqualWithAccuracy(snapshot.touches[1].position.x, 20, 0.001);
    XCTAssertEqualWithAccuracy(snapshot.touches[1].position.y, 70, 0.001);
}

- (void)testAppKitPointerCaptureIgnoresNonKeyWindowAndAppliesViewPrivacy {
    NSWindow *keyWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 200, 100)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    NSWindow *nonKeyWindow = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 200, 100)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    NSView *hiddenTouchView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 80, 80)];
    hiddenTouchView.sessionReplayPrivacyOverrides.touchPrivacy =
        FTTouchPrivacyLevelOverrideHide;
    [keyWindow.contentView addSubview:hiddenTouchView];
    FTWindowObserver *observer = [[FTWindowObserver alloc]
        initWithKeyWindowProvider:^NSWindow * _Nullable{
            return keyWindow;
        }];
    FTSessionReplayTouches *touches =
        [[FTSessionReplayTouches alloc] initWithWindowObserver:observer];

    [touches recordMouseEventType:NSEventTypeLeftMouseDown
                    buttonNumber:0
                locationInWindow:NSMakePoint(100, 90)
                          window:nonKeyWindow];
    [touches recordMouseEventType:NSEventTypeLeftMouseUp
                    buttonNumber:0
                locationInWindow:NSMakePoint(100, 90)
                          window:nonKeyWindow];
    [touches recordMouseEventType:NSEventTypeLeftMouseDown
                    buttonNumber:0
                locationInWindow:NSMakePoint(20, 20)
                          window:keyWindow];
    [touches recordMouseEventType:NSEventTypeLeftMouseUp
                    buttonNumber:0
                locationInWindow:NSMakePoint(20, 20)
                          window:keyWindow];
    [touches recordMouseEventType:NSEventTypeLeftMouseDown
                    buttonNumber:0
                locationInWindow:NSMakePoint(100, 90)
                          window:keyWindow];
    [touches recordMouseEventType:NSEventTypeLeftMouseUp
                    buttonNumber:0
                locationInWindow:NSMakePoint(100, 90)
                          window:keyWindow];

    FTTouchSnapshot *snapshot =
        [touches takeTouchSnapshotWithContext:[self showTouchesContext]];
    XCTAssertEqual(snapshot.touches.count, 2u);
    XCTAssertEqualWithAccuracy(snapshot.touches[0].position.x, 100, 0.001);
    XCTAssertEqualWithAccuracy(snapshot.touches[0].position.y, 10, 0.001);
}

- (void)testAppKitCaptureTimerUsesFixedOneHundredMillisecondNSTimer {
    XCTAssertEqualWithAccuracy(FTSessionReplayMacOSCaptureInterval, 0.1, 0.0001);
    FTScreenChangeScheduler *scheduler = [[FTScreenChangeScheduler alloc]
        initWithMinimumInterval:FTSessionReplayMacOSCaptureInterval];
    __block NSUInteger captures = 0;
    [scheduler scheduleWithOperation:^{
        captures += 1;
    }];

    XCTestExpectation *timerCreated = [self expectationWithDescription:@"NSTimer created"];
    __block NSTimer *captureTimer = nil;
    [scheduler start];
    dispatch_async(dispatch_get_main_queue(), ^{
        captureTimer = scheduler.captureTimer;
        [timerCreated fulfill];
    });
    [self waitForExpectations:@[timerCreated] timeout:1];

    XCTAssertNotNil(captureTimer);
    XCTAssertTrue([captureTimer isKindOfClass:NSTimer.class]);
    XCTAssertEqualWithAccuracy(captureTimer.timeInterval, 0.1, 0.0001);
    [captureTimer fire];
    XCTAssertTrue(captureTimer.isValid);
    [captureTimer fire];
    XCTAssertEqual(captures, 2u);
    XCTAssertEqual(scheduler.captureTimer, captureTimer);

    XCTestExpectation *timerStopped = [self expectationWithDescription:@"NSTimer stopped"];
    [scheduler stop];
    dispatch_async(dispatch_get_main_queue(), ^{
        [timerStopped fulfill];
    });
    [self waitForExpectations:@[timerStopped] timeout:1];
    XCTAssertFalse(captureTimer.isValid);
}

- (void)testDispatchSourceTimerSchedulerFiresAtRequestedInterval {
    XCTestExpectation *timerFired = [self expectationWithDescription:@"dispatch source timer fired"];
    NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
    __block NSTimeInterval elapsed = 0;
    id<FTScheduledTimer> timer =
        [FTDispatchSourceTimerScheduler.dispatchSource
            scheduleAfterInterval:FTSessionReplayMacOSCaptureInterval
                           action:^{
                               elapsed = NSProcessInfo.processInfo.systemUptime - start;
                               [timerFired fulfill];
                           }];

    XCTAssertNotNil(timer);
    [self waitForExpectations:@[timerFired] timeout:1];
    XCTAssertGreaterThanOrEqual(elapsed, FTSessionReplayMacOSCaptureInterval * 0.8);
    XCTAssertLessThan(elapsed, 0.5);
}

- (void)testAppKitCoordinatesAreNormalizedToTopLeft {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 200)];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 20, 50, 30)];
    field.stringValue = @"visible";
    [root addSubview:field];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];

    XCTAssertEqual(snapshot.nodes.count, 2u);
    CGRect frame = snapshot.nodes.lastObject.attributes.frame;
    XCTAssertEqualWithAccuracy(frame.origin.x, 10, 0.001);
    XCTAssertEqualWithAccuracy(frame.origin.y, 150, 0.001);
    XCTAssertEqualWithAccuracy(frame.size.width, 50, 0.001);
    XCTAssertEqualWithAccuracy(frame.size.height, 30, 0.001);
}

- (void)testAppKitRootViewAlwaysProducesViewportBackgroundShape {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 180)];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];

    XCTAssertEqual(wireframes.count, 1u);
    FTSRShapeWireframe *background = (FTSRShapeWireframe *)wireframes.firstObject;
    XCTAssertTrue([background isKindOfClass:FTSRShapeWireframe.class]);
    XCTAssertEqualObjects(background.x, @0);
    XCTAssertEqualObjects(background.y, @0);
    XCTAssertEqualObjects(background.width, @320);
    XCTAssertEqualObjects(background.height, @180);
    XCTAssertNotNil(background.shapeStyle.backgroundColor);
}

- (void)testPrivacyOverrideIsInheritedByAppKitSubviews {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
    root.sessionReplayPrivacyOverrides.textAndInputPrivacy =
        FTTextAndInputPrivacyLevelOverrideMaskAll;
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 180, 30)];
    field.stringValue = @"private session replay text";
    [root addSubview:field];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];
    NSPredicate *textPredicate = [NSPredicate predicateWithBlock:^BOOL(FTSRWireframe *wireframe,
                                                                       NSDictionary *bindings) {
        return [wireframe isKindOfClass:FTSRTextWireframe.class];
    }];
    FTSRTextWireframe *text =
        (FTSRTextWireframe *)[wireframes filteredArrayUsingPredicate:textPredicate].firstObject;

    XCTAssertNotNil(text);
    XCTAssertTrue([text isKindOfClass:FTSRTextWireframe.class]);
    XCTAssertNotEqualObjects(text.text, field.stringValue);
    XCTAssertFalse([text.text containsString:@"private"]);
}

- (void)testBundledAppKitImageIsRecordedWithNonBundledMasking {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 10, 40, 40)];
    imageView.image = [NSImage imageNamed:NSImageNameActionTemplate];
    [root addSubview:imageView];
    FTSRContext *context = [self allowContentContext];
    context.imagePrivacy = FTImagePrivacyLevelMaskNonBundledOnly;
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:context];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];
    NSPredicate *imagePredicate = [NSPredicate predicateWithBlock:^BOOL(FTSRWireframe *wireframe,
                                                                        NSDictionary *bindings) {
        return [wireframe isKindOfClass:FTSRImageWireframe.class];
    }];

    XCTAssertEqual([wireframes filteredArrayUsingPredicate:imagePredicate].count, 1u);
}

- (void)testAppKitImageResourceIsReusedAndEncodedOffMainWithSizeLimit {
    size_t sourceWidth = 1600;
    size_t sourceHeight = 1200;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef imageContext =
        CGBitmapContextCreate(NULL,
                             sourceWidth,
                             sourceHeight,
                             8,
                             0,
                             colorSpace,
                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast |
                                 (CGBitmapInfo)kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    XCTAssertTrue(imageContext != NULL);
    CGContextSetRGBFillColor(imageContext, 0.2, 0.4, 0.8, 1);
    CGContextFillRect(imageContext, CGRectMake(0, 0, sourceWidth, sourceHeight));
    CGImageRef sourceImage = CGBitmapContextCreateImage(imageContext);
    CGContextRelease(imageContext);
    XCTAssertTrue(sourceImage != NULL);

    NSImage *image = [[NSImage alloc] initWithCGImage:sourceImage
                                                size:NSMakeSize(sourceWidth, sourceHeight)];
    CGImageRelease(sourceImage);
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 150)];
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 10, 180, 130)];
    imageView.image = image;
    [root addSubview:imageView];
    FTViewTreeSnapshotBuilder *snapshotBuilder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];
    FTViewTreeSnapshot *firstSnapshot =
        [snapshotBuilder takeSnapshot:@[root]
                        referenceView:root
                              context:[self allowContentContext]];
    FTViewTreeSnapshot *secondSnapshot =
        [snapshotBuilder takeSnapshot:@[root]
                        referenceView:root
                              context:[self allowContentContext]];

    XCTestExpectation *processed = [self expectationWithDescription:@"image resource processed"];
    __block id<FTSRResource> firstResource = nil;
    __block id<FTSRResource> secondResource = nil;
    __block NSString *identifier = nil;
    __block NSData *pngData = nil;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        FTSessionReplayWireframesBuilder *firstWireframesBuilder =
            [[FTSessionReplayWireframesBuilder alloc]
                initWithResources:firstSnapshot.resources
                webViewSlotIDs:firstSnapshot.webViewSlotIDs];
        for (id<FTSRNodeWireframesBuilder> node in firstSnapshot.nodes) {
            [node buildWireframesWithBuilder:firstWireframesBuilder];
        }
        FTSessionReplayWireframesBuilder *secondWireframesBuilder =
            [[FTSessionReplayWireframesBuilder alloc]
                initWithResources:secondSnapshot.resources
                webViewSlotIDs:secondSnapshot.webViewSlotIDs];
        for (id<FTSRNodeWireframesBuilder> node in secondSnapshot.nodes) {
            [node buildWireframesWithBuilder:secondWireframesBuilder];
        }
        firstResource = firstWireframesBuilder.resources.firstObject;
        secondResource = secondWireframesBuilder.resources.firstObject;
        identifier = [firstResource calculateIdentifier];
        pngData = [firstResource calculateData];
        [processed fulfill];
    });
    [self waitForExpectations:@[processed] timeout:3];

    XCTAssertNotNil(firstResource);
    XCTAssertEqual(firstResource, secondResource);
    XCTAssertEqualObjects(identifier, [secondResource calculateIdentifier]);
    XCTAssertGreaterThan(pngData.length, 0u);
    CGImageSourceRef imageSource =
        CGImageSourceCreateWithData((__bridge CFDataRef)pngData, NULL);
    XCTAssertTrue(imageSource != NULL);
    NSDictionary *properties =
        CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL));
    CFRelease(imageSource);
    NSNumber *pixelWidth = properties[(__bridge NSString *)kCGImagePropertyPixelWidth];
    NSNumber *pixelHeight = properties[(__bridge NSString *)kCGImagePropertyPixelHeight];
    XCTAssertLessThanOrEqual(pixelWidth.unsignedIntegerValue, 1000u);
    XCTAssertLessThanOrEqual(pixelHeight.unsignedIntegerValue, 1000u);
}

- (void)testAppKitWKWebViewProducesSlotWireframe {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 180)];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(20, 30, 280, 120)];
    [root addSubview:webView];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];
    NSPredicate *webViewPredicate =
        [NSPredicate predicateWithBlock:^BOOL(FTSRWireframe *wireframe, NSDictionary *bindings) {
            return [wireframe isKindOfClass:FTSRWebViewWireframe.class];
        }];
    NSArray<FTSRWireframe *> *webViewWireframes =
        [wireframes filteredArrayUsingPredicate:webViewPredicate];

    XCTAssertEqual(snapshot.nodes.count, 2u);
    XCTAssertTrue([snapshot.webViewSlotIDs containsObject:@(webView.hash)]);
    XCTAssertEqual(webViewWireframes.count, 1u);
    FTSRWebViewWireframe *wireframe = (FTSRWebViewWireframe *)webViewWireframes.firstObject;
    NSString *expectedSlotID = [NSString stringWithFormat:@"%lu", webView.hash];
    XCTAssertEqualObjects(wireframe.slotId, expectedSlotID);
    XCTAssertEqualObjects(wireframe.isVisible, @YES);
}

- (void)testRepresentativeAppKitControlsProduceWireframes {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 240)];
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(10, 190, 100, 30)];
    button.title = @"Record";
    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(10, 140, 180, 24)];
    slider.minValue = 0;
    slider.maxValue = 10;
    slider.doubleValue = 4;
    NSSegmentedControl *segments =
        [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(10, 90, 180, 28)];
    segments.segmentCount = 2;
    [segments setLabel:@"First" forSegment:0];
    [segments setLabel:@"Second" forSegment:1];
    segments.selectedSegment = 1;
    NSProgressIndicator *progress =
        [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(10, 40, 180, 12)];
    progress.indeterminate = NO;
    progress.minValue = 0;
    progress.maxValue = 100;
    progress.doubleValue = 25;
    [root addSubview:button];
    [root addSubview:slider];
    [root addSubview:segments];
    [root addSubview:progress];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];

    XCTAssertEqual(snapshot.nodes.count, 5u);
    XCTAssertGreaterThanOrEqual(wireframes.count, 11u);
}

- (void)testAppKitNSSwitchProducesTrackAndThumbWireframes {
    if (@available(macOS 10.15, *)) {
        NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)];
        NSSwitch *toggle = [[NSSwitch alloc] initWithFrame:NSMakeRect(20, 30, 38, 22)];
        toggle.state = NSControlStateValueOn;
        [root addSubview:toggle];
        FTViewTreeSnapshotBuilder *builder =
            [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

        FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                              referenceView:root
                                                    context:[self allowContentContext]];
        NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];
        NSPredicate *shapePredicate =
            [NSPredicate predicateWithBlock:^BOOL(FTSRWireframe *wireframe, NSDictionary *bindings) {
                return [wireframe isKindOfClass:FTSRShapeWireframe.class];
            }];
        NSArray<FTSRShapeWireframe *> *shapes =
            (NSArray<FTSRShapeWireframe *> *)[wireframes filteredArrayUsingPredicate:shapePredicate];

        XCTAssertEqual(snapshot.nodes.count, 2u);
        XCTAssertEqual(shapes.count, 3u);
        XCTAssertEqualObjects(shapes[1].width, @38);
        XCTAssertEqualObjects(shapes[1].height, @22);
        XCTAssertEqualObjects(shapes[2].width, @18);
        XCTAssertEqualObjects(shapes[2].height, @18);
        XCTAssertGreaterThan(shapes[2].x.doubleValue, shapes[1].x.doubleValue);
    }
}

- (void)testAppKitTableHeaderProducesColumnBackgroundsAndTitles {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
    NSTableView *tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 300, 80)];
    NSTableColumn *eventColumn = [[NSTableColumn alloc] initWithIdentifier:@"Event"];
    eventColumn.width = 100;
    eventColumn.headerCell.stringValue = @"Event";
    NSTableColumn *apiColumn = [[NSTableColumn alloc] initWithIdentifier:@"API"];
    apiColumn.width = 200;
    apiColumn.headerCell.stringValue = @"API";
    [tableView addTableColumn:eventColumn];
    [tableView addTableColumn:apiColumn];
    NSTableHeaderView *headerView =
        [[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0, 70, 300, 30)];
    tableView.headerView = headerView;
    [root addSubview:headerView];
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];

    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:[self allowContentContext]];
    NSArray<FTSRWireframe *> *wireframes = [self wireframesForSnapshot:snapshot];
    NSPredicate *textPredicate =
        [NSPredicate predicateWithBlock:^BOOL(FTSRWireframe *wireframe, NSDictionary *bindings) {
            return [wireframe isKindOfClass:FTSRTextWireframe.class];
        }];
    NSArray<FTSRTextWireframe *> *texts =
        (NSArray<FTSRTextWireframe *> *)[wireframes filteredArrayUsingPredicate:textPredicate];

    XCTAssertEqual(snapshot.nodes.count, 2u);
    XCTAssertEqual(texts.count, 2u);
    XCTAssertEqualObjects(texts[0].text, @"Event");
    XCTAssertEqualObjects(texts[1].text, @"API");
    XCTAssertGreaterThan(texts[0].width.doubleValue, 0);
    XCTAssertGreaterThan(texts[1].width.doubleValue, 0);
    XCTAssertGreaterThan(texts[1].x.doubleValue, texts[0].x.doubleValue);
    XCTAssertNotNil(texts[0].shapeStyle.backgroundColor);
    XCTAssertNotNil(texts[1].shapeStyle.backgroundColor);
}

- (void)testAppKitSnapshotProducesAssociatedSegmentAndMultipartMetadata {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 180)];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 80, 180, 30)];
    field.stringValue = @"macOS session replay";
    [root addSubview:field];

    FTSRContext *context = [self allowContentContext];
    context.applicationID = @"app-macos";
    context.sessionID = @"session-macos";
    context.viewID = @"view-macos";
    FTViewTreeSnapshotBuilder *builder =
        [[FTViewTreeSnapshotBuilder alloc] initWithAdditionalNodeRecorders:nil enableSwiftUI:NO];
    FTViewTreeSnapshot *snapshot = [builder takeSnapshot:@[root]
                                          referenceView:root
                                                context:context];

    dispatch_queue_t processorQueue =
        dispatch_queue_create("com.guance.session-replay.appkit-integration-test", DISPATCH_QUEUE_SERIAL);
    FTAppKitCapturingRecordWriter *writer = [FTAppKitCapturingRecordWriter new];
    writer.writeExpectation = [self expectationWithDescription:@"snapshot processed"];
    FTResourceProcessor *resourceProcessor =
        [[FTResourceProcessor alloc] initWithQueue:processorQueue
                                   resourceWriter:[FTAppKitNoOpResourcesWriter new]];
    FTSnapshotProcessor *processor =
        [[FTSnapshotProcessor alloc] initWithQueue:processorQueue
                                     recordWriter:writer
                                resourceProcessor:resourceProcessor];
    [processor process:snapshot touchSnapshot:nil];
    [self waitForExpectations:@[writer.writeExpectation] timeout:2];

    XCTAssertNotNil(writer.recordData);
    NSDictionary *enrichedRecord =
        [NSJSONSerialization JSONObjectWithData:writer.recordData options:0 error:nil];
    XCTAssertEqualObjects(enrichedRecord[@"applicationID"], context.applicationID);
    XCTAssertEqualObjects(enrichedRecord[@"sessionID"], context.sessionID);
    XCTAssertEqualObjects(enrichedRecord[@"viewID"], context.viewID);
    XCTAssertEqual([enrichedRecord[@"records"] count], 3u);

    FTSegmentRequest *segmentRequest = [FTSegmentRequest new];
    NSDictionary *metadata = @{
        @"source": @"macos",
        @"service": @"demo-service",
        @"sdk_name": @"df_macos_rum_sdk",
    };
    [segmentRequest requestWithEvents:@[writer.recordData] parameters:metadata];
    FTSegmentJSON *segment = [segmentRequest valueForKey:@"segment"];
    NSDictionary *payload =
        [NSJSONSerialization JSONObjectWithData:[segment toJSONData] options:0 error:nil];

    XCTAssertEqualObjects(payload[@"application"][@"id"], context.applicationID);
    XCTAssertEqualObjects(payload[@"session"][@"id"], context.sessionID);
    XCTAssertEqualObjects(payload[@"view"][@"id"], context.viewID);
    XCTAssertEqualObjects(payload[@"source"], @"macos");
    XCTAssertEqualObjects(payload[@"has_full_snapshot"], @YES);
    XCTAssertEqualObjects(payload[@"records_count"], @3);

    NSMutableURLRequest *urlRequest =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/v1/write/rum/replay"]];
    NSMutableURLRequest *adaptedRequest = [segmentRequest adaptedRequest:urlRequest];
    NSString *multipartBody =
        [[NSString alloc] initWithData:adaptedRequest.HTTPBody encoding:NSISOLatin1StringEncoding];
    XCTAssertTrue([multipartBody containsString:@"name=\"app_id\""]);
    XCTAssertTrue([multipartBody containsString:context.applicationID]);
    XCTAssertTrue([multipartBody containsString:@"name=\"session_id\""]);
    XCTAssertTrue([multipartBody containsString:context.sessionID]);
    XCTAssertTrue([multipartBody containsString:@"name=\"view_id\""]);
    XCTAssertTrue([multipartBody containsString:context.viewID]);
    XCTAssertTrue([multipartBody containsString:@"name=\"source\""]);
    XCTAssertTrue([multipartBody containsString:@"macos"]);
    XCTAssertTrue([multipartBody containsString:@"name=\"sdk_name\""]);
    XCTAssertTrue([multipartBody containsString:@"df_macos_rum_sdk"]);
}

@end
