//
//  FTModuleManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/10.
//  Copyright 2024 Shanghai Guance Information Technology Co., Ltd.
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

#import "FTModuleManager.h"
#import "FTMessageReceiver.h"
NSString *const FTMessageKeyRUMContext = @"rum_context";
NSString *const FTMessageKeySRProperty = @"sr_property";
NSString *const FTMessageKeyWebViewSR = @"webView_session_replay";
NSString *const FTMessageKeyRecordsCountByViewID = @"sr_records_count_by_view_id";
NSString *const FTMessageKeySessionHasReplay = @"sr_has_replay";
NSString *const FTMessageKeyRumError = @"rum_error";
NSString *const FTMessageKeySRSampleRateUpdate = @"sr_sample_rate_update";

void *FTMessageBusQueueIdentityKey = &FTMessageBusQueueIdentityKey;

@interface FTModuleManager()
@property (nonatomic, strong, readonly) NSPointerArray *receiverArray;
@property (nonatomic, strong) NSMapTable *registerServices;
@property (nonatomic, strong) NSDictionary *srProperty;
@property (nonatomic, strong) dispatch_queue_t queue;
@end
@implementation FTModuleManager
-(instancetype)init{
    self = [super init];
    if(self){
        _queue = dispatch_queue_create("com.ft.message-bus", 0);
        dispatch_queue_set_specific(_queue,FTMessageBusQueueIdentityKey, &FTMessageBusQueueIdentityKey, NULL);
        _receiverArray = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        _registerServices = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}
+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}
- (void)notifyMessageReceivers:(NSArray *)receivers key:(NSString *)key message:(NSDictionary *)message{
    for (id receiver in receivers) {
        if ([receiver respondsToSelector:@selector(receive:message:)]) {
            [receiver receive:key message:message];
        }
    }
}
- (void)postMessageWithKey:(NSString *)key messageBlock:(nullable NSDictionary * (^)(void))messageBlock{
    dispatch_block_t block = ^{
        NSDictionary *message = messageBlock ? messageBlock() : nil;
        if (!message) {
            return;
        }
        NSArray *receivers = self.receiverArray.allObjects;
        [self notifyMessageReceivers:receivers key:key message:message];
    };
    dispatch_async(self.queue, block);
}
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message{
    [self postMessageWithKey:key message:message sync:NO];
}
- (void)postMessageWithKey:(NSString *)key message:(NSDictionary *)message sync:(BOOL)sync{
    dispatch_block_t block = ^{
        NSArray *receivers = self.receiverArray.allObjects;
        [self notifyMessageReceivers:receivers key:key message:message];
    };
    if (sync) {
        [self syncProcess:block];
    }else{
        dispatch_async(self.queue, block);
    }
}
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver{
    dispatch_async(self.queue, ^{
        [self.receiverArray compact];
        if (![self.receiverArray.allObjects containsObject:receiver]) {
            [self.receiverArray addPointer:(__bridge void *)receiver];
        }
    });
}

- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver{
    void *receiverPointer = (__bridge void *)receiver;
    dispatch_block_t block = ^{
        [self removeMessageReceiverWithPointer:receiverPointer];
    };
    if(dispatch_get_specific(FTMessageBusQueueIdentityKey) == NULL){
        dispatch_async(self.queue, block);
    }else{
        block();
    }
}
- (void)removeMessageReceiverWithPointer:(void *)receiverPointer{
    if (receiverPointer == NULL) {
        return;
    }
    for (NSUInteger i=0; i<self.receiverArray.count; i++) {
        if ([self.receiverArray pointerAtIndex:i] == receiverPointer) {
            [self.receiverArray removePointerAtIndex:i];
            break;
        }
    }
    [self.receiverArray compact];
}
- (void)registerService:(Protocol *)service instance:(id)instance{
    NSString *key = NSStringFromProtocol(service);
    [self syncProcess:^{
        [self.registerServices setObject:instance forKey:key];
    }];
}
- (id)getRegisterService:(Protocol *)service{
    NSString *key = NSStringFromProtocol(service);
    __block id instance = nil;
    [self syncProcess:^{
        instance = [self.registerServices objectForKey:key];
    }];
    return instance;
}
- (void)syncProcess{
    [self syncProcess:^{}];
}
- (void)syncProcess:(dispatch_block_t)block{
    if(dispatch_get_specific(FTMessageBusQueueIdentityKey) == NULL){
        dispatch_sync(self.queue, block);
    }else{
        block();
    }
}
@end
