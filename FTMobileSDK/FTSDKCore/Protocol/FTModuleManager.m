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
        _queue = dispatch_queue_create("com.guance.message-bus", 0);
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
- (NSDictionary *)getSRProperty{
    __block NSDictionary *property = nil;
    dispatch_sync(self.queue, ^{
        property = self.srProperty;
    });
    return property;
}
- (void)postMessage:(NSString *)key message:(NSDictionary *)message{
    dispatch_async(self.queue, ^{
        if(key == FTMessageKeySRProperty){
            self.srProperty = message;
            return;
        }
        for (id receiver in self.receiverArray) {
            if ([receiver respondsToSelector:@selector(receive:message:)]) {
                [receiver receive:key message:message];
            }
        }
    });
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
    dispatch_sync(self.queue, ^{ });
}
@end
