//
//  FTNetworkConnectivityTests.m
//  FTMobileSDKUnitTests
//
//  Created by hulilei on 2026/11/10.
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

#import <XCTest/XCTest.h>
#import <Network/Network.h>
#import <TargetConditionals.h>
#import <stdatomic.h>
#import "FTNetworkConnectivity.h"
#import "FTConstants.h"
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

// These selectors are private to the implementation. Only this subclass replaces
// them; the SDK singleton and every other XCTest keep their real system backend.
@interface FTNetworkConnectivity (ConnectivityTests)
- (nw_path_monitor_t)createPathMonitor;
- (void)startPathMonitor:(nw_path_monitor_t)monitor queue:(dispatch_queue_t)queue
          updateHandler:(nw_path_monitor_update_handler_t)handler;
- (void)cancelPathMonitor:(nw_path_monitor_t)monitor;
- (nw_path_status_t)statusForPath:(nw_path_t)path;
- (BOOL)path:(nw_path_t)path usesInterfaceType:(nw_interface_type_t)type;
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (CTTelephonyNetworkInfo *)createCellularNetworkInfo;
#endif
@end

@interface FTConnectivityGate : NSObject {
    atomic_bool _open;
}
@property (nonatomic, strong) dispatch_semaphore_t entered;
@property (nonatomic, strong) dispatch_semaphore_t released;
@property (atomic) BOOL timedOut;
- (void)pause;
- (void)open;
@end
@implementation FTConnectivityGate
- (instancetype)init {
    if ((self = [super init])) {
        atomic_init(&_open, false);
        _entered = dispatch_semaphore_create(0);
        _released = dispatch_semaphore_create(0);
    }
    return self;
}
- (void)pause {
    dispatch_semaphore_signal(self.entered);
    if (!atomic_load(&_open)) {
        self.timedOut = dispatch_semaphore_wait(self.released,
            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0;
    }
}
- (void)open {
    atomic_store(&_open, true);
    dispatch_semaphore_signal(self.released);
}
@end

@interface FTConnectivityMonitor : NSObject
@property (nonatomic, copy) nw_path_monitor_update_handler_t handler;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic) NSUInteger starts;
@property (nonatomic) NSUInteger cancels;
@end
@implementation FTConnectivityMonitor @end

@interface FTConnectivityPath : NSObject
@property (nonatomic) nw_path_status_t status;
@property (nonatomic) nw_interface_type_t interfaceType;
@property (nonatomic) uint8_t linkQuality;
@end
@implementation FTConnectivityPath @end

@interface FTConnectivityRadioInfo : NSObject
@property (nonatomic, copy) NSDictionary *serviceCurrentRadioAccessTechnology;
@property (nonatomic, copy, nullable) NSString *dataServiceIdentifier;
@end
@implementation FTConnectivityRadioInfo
- (instancetype)init {
    if ((self = [super init])) _dataServiceIdentifier = @"sim";
    return self;
}
@end

@interface FTConnectivityBackend : NSObject
@property (nonatomic, strong) NSMutableArray<FTConnectivityMonitor *> *monitors;
@property (nonatomic, strong) FTConnectivityRadioInfo *radioInfo;
@property (nonatomic, strong) FTConnectivityGate *createGate;
@property (nonatomic, strong) FTConnectivityGate *radioGate;
@property (nonatomic) NSUInteger creations;
@property (nonatomic) NSUInteger radioCreations;
@property (nonatomic) BOOL createdOnMain;
@property (nonatomic) BOOL failNextCreate;
@end
@implementation FTConnectivityBackend
- (instancetype)init {
    if ((self = [super init])) {
        _monitors = [NSMutableArray new];
        _radioInfo = [FTConnectivityRadioInfo new];
    }
    return self;
}
@end

@interface FTConnectivityUnderTest : FTNetworkConnectivity
@property (nonatomic, strong) FTConnectivityBackend *backend;
@property (nonatomic, readonly) dispatch_queue_t testQueue;
@end
@implementation FTConnectivityUnderTest
- (dispatch_queue_t)testQueue { return [self valueForKey:@"monitorQueue"]; }
- (nw_path_monitor_t)createPathMonitor {
    self.backend.creations += 1;
    self.backend.createdOnMain |= NSThread.isMainThread;
    [self.backend.createGate pause];
    if (self.backend.failNextCreate) {
        self.backend.failNextCreate = NO;
        return nil;
    }
    FTConnectivityMonitor *monitor = [FTConnectivityMonitor new];
    [self.backend.monitors addObject:monitor];
    return (nw_path_monitor_t)monitor;
}
- (void)startPathMonitor:(nw_path_monitor_t)monitor queue:(dispatch_queue_t)queue
          updateHandler:(nw_path_monitor_update_handler_t)handler {
    FTConnectivityMonitor *fake = (FTConnectivityMonitor *)monitor;
    fake.handler = handler;
    fake.queue = queue;
    fake.starts += 1;
}
- (void)cancelPathMonitor:(nw_path_monitor_t)monitor {
    // Also called from base dealloc: do not access already-destroyed subclass ivars.
    FTConnectivityMonitor *fake = (FTConnectivityMonitor *)monitor;
    fake.cancels += 1;
}
- (nw_path_status_t)statusForPath:(nw_path_t)path {
    return ((FTConnectivityPath *)path).status;
}
- (uint8_t)linkQualityForPath:(nw_path_t)path {
    return ((FTConnectivityPath *)path).linkQuality;
}
- (BOOL)path:(nw_path_t)path usesInterfaceType:(nw_interface_type_t)type {
    return ((FTConnectivityPath *)path).interfaceType == type;
}
#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (CTTelephonyNetworkInfo *)createCellularNetworkInfo {
    self.backend.radioCreations += 1;
    [self.backend.radioGate pause];
    return (CTTelephonyNetworkInfo *)self.backend.radioInfo;
}
#endif
@end

@interface FTConnectivityObserver : NSObject <FTNetworkChangeObserver>
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *events;
@property (nonatomic, copy) dispatch_block_t callback;
@end
@implementation FTConnectivityObserver
- (instancetype)init {
    if ((self = [super init])) _events = [NSMutableArray new];
    return self;
}
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)type {
    [self.events addObject:@{@"connected": @(connected), @"type": type ?: @"<nil>"}];
    if (self.callback) self.callback();
}
@end

@interface FTNetworkConnectivityTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<FTConnectivityUnderTest *> *instances;
@property (nonatomic, strong) NSMutableArray<FTConnectivityGate *> *gates;
@property (nonatomic, strong) FTConnectivityUnderTest *connectivity;
@property (nonatomic, strong) FTConnectivityBackend *backend;
@end

@implementation FTNetworkConnectivityTests
- (void)setUp {
    [super setUp];
    self.instances = [NSMutableArray new];
    self.gates = [NSMutableArray new];
    self.connectivity = [self newConnectivity];
    self.backend = self.connectivity.backend;
}
- (void)tearDown {
    // Always release gates before draining, including when a preceding assertion failed.
    for (FTConnectivityGate *gate in self.gates) [gate open];
    for (FTConnectivityUnderTest *instance in self.instances) {
        [instance stop];
        [self drain:instance];
    }
    for (FTConnectivityGate *gate in self.gates) XCTAssertFalse(gate.timedOut);
    self.connectivity = nil;
    self.backend = nil;
    self.instances = nil;
    self.gates = nil;
    [super tearDown];
}
- (FTConnectivityUnderTest *)newConnectivity {
    FTConnectivityUnderTest *instance = [FTConnectivityUnderTest new];
    instance.backend = [FTConnectivityBackend new];
    [self.instances addObject:instance];
    return instance;
}
- (FTConnectivityGate *)newGate {
    FTConnectivityGate *gate = [FTConnectivityGate new];
    [self.gates addObject:gate];
    return gate;
}
- (void)waitForGate:(FTConnectivityGate *)gate {
    XCTAssertEqual(dispatch_semaphore_wait(gate.entered,
        dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)), 0L);
}
- (void)drain:(FTConnectivityUnderTest *)instance {
    dispatch_sync(instance.testQueue, ^{});
}
- (FTConnectivityMonitor *)startAndDrain:(FTConnectivityUnderTest *)instance {
    [instance start];
    [self drain:instance];
    return instance.backend.monitors.lastObject;
}
- (FTConnectivityObserver *)observe:(FTConnectivityUnderTest *)instance {
    FTConnectivityObserver *observer = [FTConnectivityObserver new];
    [instance addNetworkObserver:observer];
    return observer;
}
- (FTConnectivityPath *)pathWithStatus:(nw_path_status_t)status type:(nw_interface_type_t)type {
    FTConnectivityPath *path = [FTConnectivityPath new];
    path.status = status;
    path.interfaceType = type;
    return path;
}
- (void)emit:(FTConnectivityMonitor *)monitor status:(nw_path_status_t)status type:(nw_interface_type_t)type {
    XCTAssertNotNil(monitor.handler);
    if (!monitor.handler || !monitor.queue) return;
    FTConnectivityPath *path = [self pathWithStatus:status type:type];
    dispatch_sync(monitor.queue, ^{ monitor.handler((nw_path_t)path); });
}

- (NSDictionary *)fieldsWithAvailable:(NSNumber *)available {
    NSMutableDictionary *fields = [@{FT_KEY_NETWORK_AVAILABLE: available} mutableCopy];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000 || __TV_OS_VERSION_MAX_ALLOWED >= 260000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, tvOS 26.0, macOS 26.0, *)) fields[@"network_signal_strength"] = @0;
#endif
    return fields;
}

- (void)testSignalStrengthMappingAndUnknownClearsPreviousMeasurement {
    XCTAssertTrue([self.connectivity respondsToSelector:@selector(networkSignalStrength)]);
    if (![self.connectivity respondsToSelector:@selector(networkSignalStrength)]) return;
    XCTAssertNil(self.connectivity.networkSignalStrength);
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    // Apple enum values are deliberately distinct from the protocol's 0/1/2/3.
    NSArray *rawValues = @[@10, @20, @30, @0, @255, @10];
    NSArray *expectedValues = @[@1, @2, @3, @0, @0, @1];
    for (NSUInteger index = 0; index < rawValues.count; index++) {
        FTConnectivityPath *path = [self pathWithStatus:nw_path_status_satisfied type:nw_interface_type_wifi];
        path.linkQuality = [rawValues[index] unsignedCharValue];
        dispatch_sync(monitor.queue, ^{ monitor.handler((nw_path_t)path); });
        NSNumber *expected = nil;
        if (@available(iOS 26.0, tvOS 26.0, macOS 26.0, *)) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000 || __TV_OS_VERSION_MAX_ALLOWED >= 260000 || __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
            expected = expectedValues[index];
#endif
        }
        XCTAssertEqualObjects(self.connectivity.networkSignalStrength, expected);
        NSMutableDictionary *fields = [@{FT_KEY_NETWORK_AVAILABLE: @YES} mutableCopy];
        [fields setValue:expected forKey:@"network_signal_strength"];
        XCTAssertEqualObjects(self.connectivity.networkResourceFields, fields);
    }
    XCTAssertEqual(observer.events.count, 1U);
}

- (void)testOldSignalCallbackCannotOverwriteRestartedMonitor {
    FTConnectivityMonitor *old = [self startAndDrain:self.connectivity];
    FTConnectivityPath *good = [self pathWithStatus:nw_path_status_satisfied type:nw_interface_type_wifi];
    good.linkQuality = 30;
    dispatch_sync(old.queue, ^{ old.handler((nw_path_t)good); });
    [self.connectivity stop];
    FTConnectivityMonitor *current = [self startAndDrain:self.connectivity];
    FTConnectivityPath *minimal = [self pathWithStatus:nw_path_status_satisfied type:nw_interface_type_wifi];
    minimal.linkQuality = 10;
    dispatch_sync(current.queue, ^{ current.handler((nw_path_t)minimal); });
    NSDictionary *snapshot = self.connectivity.networkResourceFields;
    NSMutableDictionary *expected = [[self fieldsWithAvailable:@YES] mutableCopy];
    if (expected[@"network_signal_strength"]) expected[@"network_signal_strength"] = @1;
    XCTAssertEqualObjects(snapshot, expected);
    dispatch_sync(old.queue, ^{ old.handler((nw_path_t)good); });
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, snapshot);
    // A new monitor without a measurement must clear the preceding quality.
    [self emit:current status:nw_path_status_unsatisfied type:nw_interface_type_wifi];
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, [self fieldsWithAvailable:@NO]);
}

- (void)testQueuedStartupCanBeCancelledWithoutCreatingMonitor {
    FTConnectivityGate *gate = [self newGate];
    dispatch_async(self.connectivity.testQueue, ^{ [gate pause]; });
    [self waitForGate:gate];
    [self.connectivity start];
    XCTAssertEqual(self.backend.creations, 0U);
    XCTAssertNil(self.connectivity.networkType);
    XCTAssertFalse(self.connectivity.isConnected);
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, @{});
    [self.connectivity stop];
    [gate open];
    [self drain:self.connectivity];
    XCTAssertEqual(self.backend.creations, 0U);
}

- (void)testInFlightCreationDoesNotBlockReadersOrRestart {
    FTConnectivityGate *gate = [self newGate];
    self.backend.createGate = gate;
    [self.connectivity start];
    [self waitForGate:gate];
    [self.connectivity start]; // Duplicate start must not enqueue another generation.
    [self.connectivity stop];
    [self.connectivity start];
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, @{});
    [gate open];
    [self drain:self.connectivity];
    XCTAssertEqual(self.backend.creations, 2U);
    XCTAssertFalse(self.backend.createdOnMain);
    XCTAssertEqual(self.backend.monitors.count, 2U);
    if (self.backend.monitors.count != 2) return;
    FTConnectivityMonitor *old = self.backend.monitors[0], *current = self.backend.monitors[1];
    XCTAssertEqual(old.starts, 0U);
    XCTAssertEqual(old.cancels, 1U);
    XCTAssertEqual(current.starts, 1U);
    XCTAssertEqual(current.cancels, 0U);
    XCTAssertEqual(current.queue, self.connectivity.testQueue);
}

- (void)testAvailabilityInterfaceMappingAndDuplicateNotifications {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    NSArray<NSDictionary *> *cases = @[
        @{@"status": @(nw_path_status_satisfied), @"interface": @(nw_interface_type_wifi), @"connected": @YES, @"available": @YES, @"type": @"wifi", @"count": @1},
        @{@"status": @(nw_path_status_satisfied), @"interface": @(nw_interface_type_wifi), @"connected": @YES, @"available": @YES, @"type": @"wifi", @"count": @1},
        @{@"status": @(nw_path_status_satisfied), @"interface": @(nw_interface_type_wired), @"connected": @YES, @"available": @YES, @"type": @"ethernet", @"count": @2},
        @{@"status": @(nw_path_status_unsatisfied), @"interface": @(nw_interface_type_wifi), @"connected": @NO, @"available": @NO, @"type": @"unknown", @"count": @3},
        @{@"status": @(nw_path_status_satisfiable), @"interface": @(nw_interface_type_wifi), @"connected": @YES, @"available": @NO, @"type": @"wifi", @"count": @4}
    ];
    for (NSDictionary *entry in cases) {
        [self emit:monitor status:[entry[@"status"] intValue] type:[entry[@"interface"] intValue]];
        XCTAssertEqual(self.connectivity.isConnected, [entry[@"connected"] boolValue]);
        XCTAssertEqualObjects(self.connectivity.networkResourceFields, [self fieldsWithAvailable:entry[@"available"]]);
        XCTAssertEqualObjects(self.connectivity.networkType, entry[@"type"]);
        XCTAssertEqual(observer.events.count, [entry[@"count"] unsignedIntegerValue]);
        XCTAssertEqualObjects(observer.events.lastObject, (@{@"connected": entry[@"connected"], @"type": entry[@"type"]}));
    }
    XCTAssertEqual(self.backend.radioCreations, 0U);
}

- (void)testStoppedAndOldGenerationCallbacksCannotReplaceCurrentState {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *old = [self startAndDrain:self.connectivity];
    [self emit:old status:nw_path_status_satisfied type:nw_interface_type_wifi];
    [self.connectivity stop];
    [self emit:old status:nw_path_status_unsatisfied type:nw_interface_type_wifi];
    XCTAssertEqualObjects(self.connectivity.networkType, @"wifi");
    XCTAssertEqual(observer.events.count, 1U);
    XCTAssertEqual(old.cancels, 1U);
    FTConnectivityMonitor *current = [self startAndDrain:self.connectivity];
    XCTAssertNotEqual(current, old);
    [self emit:current status:nw_path_status_satisfied type:nw_interface_type_wired];
    [self emit:old status:nw_path_status_satisfied type:nw_interface_type_wifi];
    XCTAssertEqualObjects(self.connectivity.networkType, @"ethernet");
    XCTAssertEqual(observer.events.count, 2U);
}

- (void)testObserverCanStopAndRestartReentrantly {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *old = [self startAndDrain:self.connectivity];
    FTConnectivityUnderTest *instance = self.connectivity;
    observer.callback = ^{ [instance stop]; [instance start]; };
    [self emit:old status:nw_path_status_satisfied type:nw_interface_type_wifi];
    observer.callback = nil;
    [self drain:instance];
    XCTAssertEqual(old.cancels, 1U);
    XCTAssertEqual(self.backend.creations, 2U);
    XCTAssertEqual(self.backend.monitors.lastObject.starts, 1U);
}

- (void)testRemovingObserverStopsNotifications {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_wifi];
    [self.connectivity removeNetworkObserver:observer];
    [self emit:monitor status:nw_path_status_unsatisfied type:nw_interface_type_wifi];
    XCTAssertEqual(observer.events.count, 1U);
}

- (void)testDelayedObserverCannotNotifyNextObserverAfterRestart {
    FTConnectivityObserver *first = [self observe:self.connectivity], *second = [self observe:self.connectivity];
    FTConnectivityMonitor *old = [self startAndDrain:self.connectivity];
    FTConnectivityGate *gate = [self newGate];
    first.callback = ^{ [gate pause]; };
    FTConnectivityPath *path = [self pathWithStatus:nw_path_status_satisfied type:nw_interface_type_wifi];
    dispatch_async(old.queue, ^{ old.handler((nw_path_t)path); });
    [self waitForGate:gate];
    [self.connectivity stop];
    [self.connectivity start];
    [gate open];
    [self drain:self.connectivity];
    first.callback = nil;
    XCTAssertEqual(first.events.count, 1U);
    XCTAssertEqual(second.events.count, 0U);
    [self emit:self.backend.monitors.lastObject status:nw_path_status_satisfied type:nw_interface_type_wired];
    XCTAssertEqual(first.events.count, 2U);
    XCTAssertEqual(second.events.count, 1U);
}

- (void)testQueuedStartupDoesNotRetainAbandonedOwner {
    FTConnectivityGate *gate = [self newGate];
    FTConnectivityBackend *backend = [FTConnectivityBackend new];
    __weak FTConnectivityUnderTest *weakOwner;
    dispatch_queue_t queue;
    @autoreleasepool {
        FTConnectivityUnderTest *owner = [FTConnectivityUnderTest new];
        owner.backend = backend;
        weakOwner = owner;
        queue = owner.testQueue;
        dispatch_async(queue, ^{ [gate pause]; });
        [self waitForGate:gate];
        [owner start];
    }
    XCTAssertNil(weakOwner);
    [gate open];
    dispatch_sync(queue, ^{});
    XCTAssertEqual(backend.creations, 0U);
}

- (void)testFailedCreationRetriesAndConcurrentStartsCoalesce {
    self.backend.failNextCreate = YES;
    [self startAndDrain:self.connectivity];
    XCTAssertEqual(self.backend.creations, 1U);
    XCTAssertEqual(self.backend.monitors.count, 0U);
    dispatch_group_t callers = dispatch_group_create();
    FTConnectivityUnderTest *instance = self.connectivity;
    for (NSUInteger index = 0; index < 64; index++) {
        dispatch_group_async(callers, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ [instance start]; });
    }
    XCTAssertEqual(dispatch_group_wait(callers, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)), 0L);
    [self drain:instance];
    XCTAssertEqual(self.backend.creations, 2U);
    XCTAssertEqual(self.backend.monitors.count, 1U);
    XCTAssertEqual(self.backend.monitors.lastObject.starts, 1U);
}

- (void)testConcurrentStartStopCancelsEveryCreatedMonitorExactlyOnce {
    dispatch_group_t callers = dispatch_group_create();
    FTConnectivityUnderTest *instance = self.connectivity;
    for (NSUInteger index = 0; index < 32; index++) {
        dispatch_group_async(callers, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            for (NSUInteger iteration = 0; iteration < 8; iteration++) { [instance start]; [instance stop]; }
        });
    }
    XCTAssertEqual(dispatch_group_wait(callers, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)), 0L);
    [instance stop];
    [self drain:instance];
    for (FTConnectivityMonitor *monitor in self.backend.monitors) {
        XCTAssertLessThanOrEqual(monitor.starts, 1U);
        XCTAssertEqual(monitor.cancels, 1U);
    }
    FTConnectivityMonitor *replacement = [self startAndDrain:instance];
    XCTAssertEqual(replacement.starts, 1U);
    XCTAssertEqual(replacement.cancels, 0U);
}

- (void)testDeallocationCancelsActiveMonitor {
    FTConnectivityBackend *backend = [FTConnectivityBackend new];
    __weak FTConnectivityUnderTest *weakOwner;
    @autoreleasepool {
        FTConnectivityUnderTest *owner = [FTConnectivityUnderTest new];
        owner.backend = backend;
        weakOwner = owner;
        [self startAndDrain:owner];
    }
    XCTAssertNil(weakOwner);
    XCTAssertEqual(backend.monitors.count, 1U);
    XCTAssertEqual(backend.monitors.lastObject.cancels, 1U);
}

- (void)testBackendStateIsIsolatedBetweenInstances {
    FTConnectivityUnderTest *other = [self newConnectivity];
    FTConnectivityObserver *first = [self observe:self.connectivity], *second = [self observe:other];
    FTConnectivityMonitor *left = [self startAndDrain:self.connectivity], *right = [self startAndDrain:other];
    [self emit:left status:nw_path_status_satisfied type:nw_interface_type_wifi];
    XCTAssertEqualObjects(self.connectivity.networkType, @"wifi");
    XCTAssertNil(other.networkType);
    XCTAssertEqual(second.events.count, 0U);
    [self emit:right status:nw_path_status_satisfied type:nw_interface_type_wired];
    XCTAssertEqualObjects(other.networkType, @"ethernet");
    XCTAssertEqualObjects(self.connectivity.networkType, @"wifi");
    XCTAssertEqual(first.events.count, 1U);
    XCTAssertEqual(second.events.count, 1U);
    XCTAssertEqual(self.backend.creations, 1U);
    XCTAssertEqual(other.backend.creations, 1U);
}

#if TARGET_OS_IOS && !TARGET_OS_MACCATALYST
- (void)testCellularTypeFollowsTheActiveDataService {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{
        @"sim-a": CTRadioAccessTechnologyLTE,
        @"sim-b": CTRadioAccessTechnologyNR
    };
    NSArray *services = @[@"sim-a", @"sim-b", @"sim-a"];
    NSArray *expectedTypes = @[@"4G", @"5G", @"4G"];
    for (NSUInteger index = 0; index < services.count; index++) {
        self.backend.radioInfo.dataServiceIdentifier = services[index];
        [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
        XCTAssertEqualObjects(self.connectivity.networkType, expectedTypes[index]);
        XCTAssertEqualObjects(observer.events.lastObject[@"type"], expectedTypes[index]);
        XCTAssertEqual(observer.events.count, index + 1);
        XCTAssertTrue(self.connectivity.isConnected);
        XCTAssertEqualObjects(self.connectivity.networkResourceFields, [self fieldsWithAvailable:@YES]);
    }
    XCTAssertEqual(self.backend.radioCreations, 1U);
}

- (void)testMissingDataServiceDoesNotGuessFromOtherSIMs {
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{
        @"sim-a": CTRadioAccessTechnologyLTE,
        @"sim-b": CTRadioAccessTechnologyNR
    };
    for (id identifier in @[NSNull.null, @"", @"unregistered-sim"]) {
        self.backend.radioInfo.dataServiceIdentifier = identifier == NSNull.null ? nil : identifier;
        [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
        XCTAssertEqualObjects(self.connectivity.networkType, @"unknown");
        XCTAssertTrue(self.connectivity.isConnected);
        XCTAssertEqualObjects(self.connectivity.networkResourceFields, [self fieldsWithAvailable:@YES]);
    }
    self.backend.radioInfo.dataServiceIdentifier = @"sim-a";
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = nil;
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
    XCTAssertEqualObjects(self.connectivity.networkType, @"unknown");
}

- (void)testCellularInfoIsLazyAndRadioChangesAreNotDeduplicated {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_wifi];
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_wired];
    XCTAssertEqual(self.backend.radioCreations, 0U);
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{@"sim": CTRadioAccessTechnologyLTE};
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
    XCTAssertEqualObjects(self.connectivity.networkType, @"4G");
    XCTAssertEqual(self.backend.radioCreations, 1U);
    XCTAssertEqual(observer.events.count, 3U);
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{@"sim": CTRadioAccessTechnologyNR};
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
    XCTAssertEqualObjects(self.connectivity.networkType, @"5G");
    XCTAssertEqual(observer.events.count, 4U);
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
    XCTAssertEqual(observer.events.count, 4U);
    XCTAssertEqual(self.backend.radioCreations, 1U);
}

- (void)testCellularGenerationsAndMissingRadioInfoKeepExactMappings {
    FTConnectivityMonitor *monitor = [self startAndDrain:self.connectivity];
    NSArray *mappings = @[@[CTRadioAccessTechnologyEdge, @"2G"], @[CTRadioAccessTechnologyWCDMA, @"3G"],
                          @[CTRadioAccessTechnologyLTE, @"4G"], @[CTRadioAccessTechnologyNRNSA, @"5G"], @[CTRadioAccessTechnologyNR, @"5G"]];
    for (NSArray *mapping in mappings) {
        self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{@"sim": mapping[0]};
        [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
        XCTAssertEqualObjects(self.connectivity.networkType, mapping[1]);
        XCTAssertEqualObjects(self.connectivity.networkResourceFields, [self fieldsWithAvailable:@YES]);
    }
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{};
    [self emit:monitor status:nw_path_status_satisfied type:nw_interface_type_cellular];
    XCTAssertEqualObjects(self.connectivity.networkType, @"unknown");
    XCTAssertEqual(self.backend.radioCreations, 1U);
}

- (void)testCancelledSlowCellularResolutionCannotPublishOldState {
    FTConnectivityObserver *observer = [self observe:self.connectivity];
    FTConnectivityMonitor *old = [self startAndDrain:self.connectivity];
    self.backend.radioInfo.serviceCurrentRadioAccessTechnology = @{@"sim": CTRadioAccessTechnologyLTE};
    FTConnectivityGate *gate = [self newGate];
    self.backend.radioGate = gate;
    FTConnectivityPath *path = [self pathWithStatus:nw_path_status_satisfied type:nw_interface_type_cellular];
    dispatch_async(old.queue, ^{ old.handler((nw_path_t)path); });
    [self waitForGate:gate];
    [self.connectivity stop];
    [self.connectivity start];
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, @{});
    [gate open];
    [self drain:self.connectivity];
    XCTAssertEqual(observer.events.count, 0U);
    XCTAssertNil(self.connectivity.networkType);
    XCTAssertEqualObjects(self.connectivity.networkResourceFields, @{});
    [self emit:self.backend.monitors.lastObject status:nw_path_status_satisfied type:nw_interface_type_wifi];
    XCTAssertEqual(observer.events.count, 1U);
    XCTAssertEqualObjects(self.connectivity.networkType, @"wifi");
}
#endif
@end
