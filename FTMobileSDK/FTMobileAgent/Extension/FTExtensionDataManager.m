//
//  FTExtensionDataManager.m
//  FTMobileExtension
//
//  Created by hulilei on 2022/9/9.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
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


#import "FTExtensionDataManager.h"
#import "FTConstants.h"
void *FTAppExtensionQueueTag = &FTAppExtensionQueueTag;

@interface FTExtensionDataManager()
@property (nonatomic, strong) dispatch_queue_t appExtensionQueue;
@property (nonatomic, strong) NSMutableDictionary *filePaths;
@end
@implementation FTExtensionDataManager
+ (instancetype)sharedInstance {
    static FTExtensionDataManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[FTExtensionDataManager alloc] init];
    });
    return manager;
}
- (instancetype)init {
    if (self = [super init]) {
        self.appExtensionQueue = dispatch_queue_create("com.ft.FTMobileExtension", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(self.appExtensionQueue, FTAppExtensionQueueTag, &FTAppExtensionQueueTag, NULL);
        _filePaths = [[NSMutableDictionary alloc]init];
        _maxCount = NSIntegerMax;
    }
    return self;
}

- (void)setGroupIdentifierArray:(NSArray *)groupIdentifierArray {
    dispatch_block_t block = ^() {
        self->_groupIdentifierArray = groupIdentifierArray;
    };
    if (dispatch_get_specific(FTAppExtensionQueueTag)) {
        block();
    } else {
        dispatch_async(self.appExtensionQueue, block);
    }
}
- (NSArray *)groupIdentifierArray {
    @try {
        __block NSArray *groupArray = nil;
        dispatch_block_t block = ^() {
            groupArray = self->_groupIdentifierArray;
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return groupArray;
    } @catch (NSException *exception) {
        return nil;
    }
}
-(void)writeRumConfig:(NSDictionary *)rumConfig{
    @try {
        dispatch_block_t block = ^() {
            [self.groupIdentifierArray enumerateObjectsUsingBlock:^(NSString  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:obj];
                [userDefaults setObject:rumConfig forKey:@"RUM_CONFIG"];
                [userDefaults synchronize];
            }];
        };
        
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
    } @catch (NSException *exception) {
        
    }
}
-(void)writeTraceConfig:(NSDictionary *)traceConfig{
    @try {
        dispatch_block_t block = ^() {
            [self.groupIdentifierArray enumerateObjectsUsingBlock:^(NSString  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:obj];
                [userDefaults setObject:traceConfig forKey:@"TRACE_CONFIG"];
                [userDefaults synchronize];
            }];
        };
        
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
    } @catch (NSException *exception) {
        
    }
}
-(void)writeLoggerConfig:(NSDictionary *)loggerConfig{
    @try {
        dispatch_block_t block = ^() {
            [self.groupIdentifierArray enumerateObjectsUsingBlock:^(NSString  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:obj];
                [userDefaults setObject:loggerConfig forKey:@"LOGGER_CONFIG"];
                [userDefaults synchronize];
            }];
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
    } @catch (NSException *exception) {
        
    }
}
-(NSDictionary *)getRumConfigWithGroupIdentifier:(NSString *)groupIdentifier{
    @try {
        __block NSDictionary *config = nil;

        dispatch_block_t block = ^() {
            NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:groupIdentifier];
            config = [userDefaults valueForKey:@"RUM_CONFIG"];
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return config;
    } @catch (NSException *exception) {
        return nil;
    }
}
-(NSDictionary *)getTraceConfigWithGroupIdentifier:(NSString *)groupIdentifier{
    @try {
        __block NSDictionary *config = nil;

        dispatch_block_t block = ^() {
            NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:groupIdentifier];
            config = [userDefaults valueForKey:@"TRACE_CONFIG"];
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return config;
    } @catch (NSException *exception) {
        return nil;
    }
}
-(NSDictionary *)getLoggerConfigWithGroupIdentifier:(NSString *)groupIdentifier{
    @try {
        __block NSDictionary *config = nil;

        dispatch_block_t block = ^() {
            NSUserDefaults *userDefaults = [[NSUserDefaults alloc]initWithSuiteName:groupIdentifier];
            config = [userDefaults valueForKey:@"LOGGER_CONFIG"];
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return config;
    } @catch (NSException *exception) {
        return nil;
    }
}
- (NSUInteger)fileDataCountForGroupIdentifier:(NSString *)groupIdentifier {
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return 0;
        }
        
        __block NSUInteger count = 0;
        dispatch_block_t block = ^() {
            NSString *path = [self filePathForApplicationGroupIdentifier:groupIdentifier];
            NSArray *array = [[NSMutableArray alloc] initWithContentsOfFile:path];
            count = array.count;
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return count;
    } @catch (NSException *exception) {
        return 0;
    }
}
- (NSString *)filePathForApplicationGroupIdentifier:(NSString *)groupIdentifier {
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return nil;
        }
        __block NSString *filePath = nil;
        dispatch_block_t block = ^() {
            NSURL *pathUrl = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupIdentifier] URLByAppendingPathComponent:@"ft_event_data.plist"];
            filePath = pathUrl.path;
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return filePath;
    } @catch (NSException *exception) {
        return nil;
    }
}
- (BOOL)writeRumEventType:(NSString *)eventType tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm groupIdentifier:(NSString *)groupIdentifier {
    @try {
        if (![eventType isKindOfClass:NSString.class] || !eventType.length) {
            return NO;
        }
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return NO;
        }
        if (fields && ![fields isKindOfClass:NSDictionary.class]) {
            return NO;
        }
        if (tags && ![tags isKindOfClass:NSDictionary.class]) {
            return NO;
        }
        NSDictionary *event = @{@"dataType":FT_DATA_TYPE_RUM,
                                @"eventType": eventType,
                                @"fields": fields?fields:@{},
                                @"tags": tags?tags:@{},
                                @"tm":[NSNumber numberWithLongLong:tm]};
        return  [self writeEvent:event groupIdentifier:groupIdentifier];
    } @catch (NSException *exception) {
        return NO;
    }
}
- (BOOL)writeLoggerEvent:(int)status content:(NSString *)content tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm groupIdentifier:(NSString *)groupIdentifier{
    @try {
        if (![content isKindOfClass:NSString.class] || !content.length) {
            return NO;
        }
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return NO;
        }
        if (fields && ![fields isKindOfClass:NSDictionary.class]) {
            return NO;
        }
        if (tags && ![tags isKindOfClass:NSDictionary.class]) {
            return NO;
        }
        NSDictionary *event = @{@"dataType":FT_DATA_TYPE_LOGGING,
                                @"status":@(status),
                                @"content":content,
                                @"fields": fields?fields:@{},
                                @"tags": tags?tags:@{},
                                @"tm":[NSNumber numberWithLongLong:tm]};
        return [self writeEvent:event groupIdentifier:groupIdentifier];
    } @catch (NSException *exception) {
        return NO;
    }
}
- (BOOL)writeEvent:(NSDictionary *)event groupIdentifier:(NSString *)groupIdentifier {
    __block BOOL result = NO;
    dispatch_block_t block = ^{
        NSString *path = [self.filePaths objectForKey:groupIdentifier];
        if(!path){
            path = [self filePathForApplicationGroupIdentifier:groupIdentifier];
            if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            }
            [self.filePaths setValue:path forKey:groupIdentifier];
        }
        NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:path];
        if (array.count) {
            if(array.count>=self.maxCount){
                [array removeObjectAtIndex:0];
            }
            [array addObject:event];
        } else {
            array = [NSMutableArray arrayWithObject:event];
        }
        NSError *err = NULL;
        NSData *data= [NSPropertyListSerialization dataWithPropertyList:array
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                                options:0
                                                                  error:&err];
        if (path.length && data.length) {
            result = [data  writeToFile:path options:NSDataWritingAtomic error:nil];
        }
    };
    if (dispatch_get_specific(FTAppExtensionQueueTag)) {
        block();
    } else {
        dispatch_sync(self.appExtensionQueue, block);
    }
    return result;
}

- (NSArray *)readAllEventsWithGroupIdentifier:(NSString *)groupIdentifier {
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return @[];
        }
        __block NSArray *dataArray = @[];
        dispatch_block_t block = ^() {
            NSString *path = [self filePathForApplicationGroupIdentifier:groupIdentifier];
            NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:path];
            dataArray = array;
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return dataArray;
    } @catch (NSException *exception) {
        return @[];
    }
}

- (BOOL)deleteEventsWithGroupIdentifier:(NSString *)groupIdentifier {
    @try {
        if (![groupIdentifier isKindOfClass:NSString.class] || !groupIdentifier.length) {
            return NO;
        }
        __block BOOL result = NO;
        dispatch_block_t block = ^{
            NSString *path = [self filePathForApplicationGroupIdentifier:groupIdentifier];
            NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:path];
            [array removeAllObjects];
            NSData *data= [NSPropertyListSerialization dataWithPropertyList:array
                                                                     format:NSPropertyListBinaryFormat_v1_0
                                                                    options:0
                                                                      error:nil];
            if (path.length && data.length) {
                result = [data  writeToFile:path options:NSDataWritingAtomic error:nil];
            }
        };
        if (dispatch_get_specific(FTAppExtensionQueueTag)) {
            block();
        } else {
            dispatch_sync(self.appExtensionQueue, block);
        }
        return result ;
    } @catch (NSException *exception) {
        return NO;
    }
}
@end