//
//  FTHeatmapIdentifierStore.m
//  FTMobileAgent
//
//  Created by hulilei on 2026/6/11.
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
