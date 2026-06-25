//
//  FTHeatmapIdentifierStore.m
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
//  Copyright © 2026 hll. All rights reserved.
//

#import "FTHeatmapIdentifierStore.h"

@interface FTHeatmapIdentifierStore ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) NSDictionary<NSValue *, FTHeatmapIdentifier *> *identifiers;
@property (nonatomic, assign) BOOL heatmapEnabled;
@end

@implementation FTHeatmapIdentifierStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.ft.heatmap-identifier-store", DISPATCH_QUEUE_CONCURRENT);
        _identifiers = @{};
        _heatmapEnabled = NO;
    }
    return self;
}

- (void)setHeatmapIdentifiers:(NSDictionary<NSValue *,FTHeatmapIdentifier *> *)heatmapIdentifiers {
    NSDictionary *identifiers = [heatmapIdentifiers copy] ?: @{};
    dispatch_barrier_sync(self.queue, ^{
        self.identifiers = identifiers;
    });
}

- (BOOL)enableHeatmap {
    return _heatmapEnabled;
}

- (void)setEnableHeatmap:(BOOL)enable {
    _heatmapEnabled = enable;
}

- (FTHeatmapIdentifier *)heatmapIdentifierForObject:(id)object {
    NSValue *key = [FTHeatmapIdentifier objectIdentifierForObject:object];
    if (!key) {
        return nil;
    }
    __block FTHeatmapIdentifier *identifier = nil;
    dispatch_sync(self.queue, ^{
        identifier = self.identifiers[key];
    });
    return identifier;
}

@end
