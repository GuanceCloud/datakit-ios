//
//  FTResourceWriter.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/25.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTResourceWriter.h"
#import "FTSRRecord.h"
#import "FTFileWriter.h"
#import <pthread.h>

int const FT_RESOURCE_CURRENT_STORE_VERSION = 1;
NSString *const FT_StoreCreationKey = @"ft-store-creation";
NSString *const FT_KnownResourcesKey = @"ft-known-resources";

@interface FTResourceWriter()
@property (nonatomic, strong) NSMutableSet *knownIdentifiers;
@property (nonatomic, assign) pthread_rwlock_t lock;
@end
@implementation FTResourceWriter

- (instancetype)init{
    self = [super init];
    if(self){
        _knownIdentifiers = [[NSMutableSet alloc]init];
        pthread_rwlock_init(&_lock,NULL);
    }
    return self;
}
-(NSMutableSet *)knownIdentifiers{
    NSMutableSet *sets;
    pthread_rwlock_rdlock(&_lock);
    sets = _knownIdentifiers;
    pthread_rwlock_unlock(&_lock);
    return sets;
}
- (void)unionSet:(NSSet *)set{
    pthread_rwlock_wrlock(&_lock);
    [self.knownIdentifiers unionSet:set];
    pthread_rwlock_unlock(&_lock);
}
- (void)write:(NSArray<FTEnrichedResource*>*)resources{
    NSMutableArray *unknownResources = [NSMutableArray new];
    [resources enumerateObjectsUsingBlock:^(FTEnrichedResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(![self.knownIdentifiers containsObject:obj.identifier]){
            [self.writer write:obj];
            [unknownResources addObject:obj.identifier];
        }
    }];
    [self unionSet:[NSSet setWithArray:unknownResources]];
}
@end
