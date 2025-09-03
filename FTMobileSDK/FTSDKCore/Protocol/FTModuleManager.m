//
//  FTModuleManager.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/7/10.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTModuleManager.h"
#import "FTMessageReceiver.h"
NSString *const FTMessageKeyRUMContext = @"rum_context";
NSString *const FTMessageKeySRProperty = @"sr_property";
NSString *const FTMessageKeyWebViewSR = @"webView_session_replay";
NSString *const FTMessageKeyRecordsCountByViewID = @"sr_records_count_by_view_id";
NSString *const FTMessageKeySessionHasReplay = @"sr_has_replay";
NSString *const FTMessageKeyRumError = @"rum_error";

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
- (void)postMessage:(NSString *)key messageBlock:(nullable NSDictionary * (^)(void))messageBlock{
    dispatch_block_t block = ^{
        NSDictionary *message = messageBlock();
        if (!message) {
            return;
        }
        for (id receiver in self.receiverArray) {
            if ([receiver respondsToSelector:@selector(receive:message:)]) {
                [receiver receive:key message:message];
            }
        }
    };
    dispatch_async(self.queue, block);
}
- (void)postMessage:(NSString *)key message:(NSDictionary *)message{
    [self postMessage:key message:message sync:NO];
}
- (void)postMessage:(NSString *)key message:(NSDictionary *)message sync:(BOOL)sync{
    dispatch_block_t block = ^{
        for (id receiver in self.receiverArray) {
            if ([receiver respondsToSelector:@selector(receive:message:)]) {
                [receiver receive:key message:message];
            }
        }
    };
    if (sync) {
        [self syncProcess:block];
    }else{
        dispatch_async(self.queue, block);
    }
}
- (void)addMessageReceiver:(id<FTMessageReceiver>)receiver{
    dispatch_async(self.queue, ^{
        if (![self.receiverArray.allObjects containsObject:receiver]) {
            [self.receiverArray addPointer:(__bridge void *)receiver];
        }
    });
}

- (void)removeMessageReceiver:(id<FTMessageReceiver>)receiver{
    dispatch_sync(self.queue, ^{
        for (NSUInteger i=0; i<self.receiverArray.count; i++) {
            if ([self.receiverArray pointerAtIndex:i] == (__bridge void *)receiver) {
                [self.receiverArray removePointerAtIndex:i];
                break;
            }
        }
    });
}
- (void)registerService:(Protocol *)service instance:(id)instance{
    NSString *key = NSStringFromProtocol(service);
    [self.registerServices setObject:instance forKey:key];
}
- (id)getRegisterService:(Protocol *)service{
    NSString *key = NSStringFromProtocol(service);
    return [self.registerServices objectForKey:key];
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
