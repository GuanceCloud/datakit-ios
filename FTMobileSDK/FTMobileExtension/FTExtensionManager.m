//
//  FTExtensionManager.m
//  FTMobileExtension
//
//  Created by 胡蕾蕾 on 2020/11/13.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTExtensionManager.h"
#import "FTLog.h"
#import "FTExtensionExceptionHandler.h"
@interface FTExtensionManager ()
@property (nonatomic, copy) NSString *pathStr;
@end
@implementation FTExtensionManager
static FTExtensionManager *sharedInstance = nil;
+ (instancetype)sharedInstance{
    NSAssert(sharedInstance, @"请先使用 startWithApplicationGroupIdentifier: 初始化");
    return sharedInstance;
}
+ (void)startWithApplicationGroupIdentifier:(NSString *)groupIdentifer{    NSAssert((groupIdentifer.length!=0 ), @"请填写Group Identifier");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FTExtensionManager alloc]initWithGroupIdentifier:groupIdentifer];
    });

}
-(instancetype)initWithGroupIdentifier:(NSString *)identifier{
    self = [super init];
    if (self) {
        self.pathStr =[[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:identifier] URLByAppendingPathComponent:@"ft_crash_data.plist"].path;
        [self startTrackCrash];
    }
    return self;
}
- (void)startTrackCrash{
    FTExtensionExceptionHandler *handler = [[FTExtensionExceptionHandler alloc]init];
    __weak typeof(self) weakSelf = self;
    [handler hookWithBlock:^(NSDictionary * _Nonnull content, NSNumber * _Nonnull tm) {
        //主线程 即将crash
        [weakSelf writeCrash:content tm:tm];
    }];
}
- (BOOL)writeCrash:(NSDictionary *)field tm:(NSNumber *)tm{
    @try {
        if (![field isKindOfClass:NSDictionary.class] || !field) {
            return NO;
        }
        if(![[NSFileManager defaultManager] fileExistsAtPath:self.pathStr]) {
            BOOL success = [[NSFileManager defaultManager] createFileAtPath:self.pathStr contents:nil attributes:nil];
            if (success) {
                ZYLog(@"Create Group File Success!");
            }
        }
        ZYDebug(@"writeCrash content :%@\n tm:%@",field,tm);
        NSDictionary *event = @{@"field":field,@"tm":tm};
        NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:self.pathStr];
        if (array.count) {
            [array addObject:event];
        } else {
            array = [NSMutableArray arrayWithObject:event];
        }
        NSError *err = NULL;
        BOOL result = NO;
        NSData *data= [NSPropertyListSerialization dataWithPropertyList:array
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                                options:0
                                                                  error:&err];
        if (self.pathStr.length && data.length) {
            result = [data  writeToFile:self.pathStr options:NSDataWritingAtomic error:nil];
        }
        return result;
    } @catch (NSException *exception) {
        return NO;
    }
    
}

- (NSArray *)getCrashData{
    @try {
        NSArray *array = [[NSArray alloc] initWithContentsOfFile:self.pathStr];
        return array;
    } @catch (NSException *exception) {
        return @[];
    }
    
}
- (BOOL)deleteEvents{
    @try {
        BOOL result = NO;
        NSMutableArray *array = [[NSMutableArray alloc] initWithContentsOfFile:self.pathStr];
        [array removeAllObjects];
        NSData *data= [NSPropertyListSerialization dataWithPropertyList:array
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                                options:0
                                                                  error:nil];
        if (self.pathStr.length && data.length) {
            result = [data  writeToFile:self.pathStr options:NSDataWritingAtomic error:nil];
        }
        
        return result ;
    } @catch (NSException *exception) {
        return NO;
    }
}
+ (void)enableLog:(BOOL)enable{
    [FTLog enableLog:enable];
}
@end
