//
//  FMDatabaseQueue.m
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "ZY_FMDatabaseQueue.h"
#import "ZY_FMDatabase.h"
#import "FTLog.h"
#if ZY_FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

typedef NS_ENUM(NSInteger, ZY_FMDBTransaction) {
    ZY_FMDBTransactionExclusive,
    ZY_FMDBTransactionDeferred,
    ZY_FMDBTransactionImmediate,
};

/*
 
 Note: we call [self retain]; before using dispatch_sync, just incase 
 FMDatabaseQueue is released on another thread and we're in the middle of doing
 something in dispatch_sync
 
 */

/*
 * A key used to associate the FMDatabaseQueue object with the dispatch_queue_t it uses.
 * This in turn is used for deadlock detection by seeing if inDatabase: is called on
 * the queue's dispatch queue, which should not happen and causes a deadlock.
 */
static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;

@interface ZY_FMDatabaseQueue () {
    dispatch_queue_t    _queue;
    ZY_FMDatabase          *_db;
}
@end

@implementation ZY_FMDatabaseQueue

+ (instancetype)databaseQueueWithPath:(NSString *)aPath {
    ZY_FMDatabaseQueue *q = [[self alloc] initWithPath:aPath];
    
    ZY_FMDBAutorelease(q);
    
    return q;
}

+ (instancetype)databaseQueueWithURL:(NSURL *)url {
    return [self databaseQueueWithPath:url.path];
}

+ (instancetype)databaseQueueWithPath:(NSString *)aPath flags:(int)openFlags {
    ZY_FMDatabaseQueue *q = [[self alloc] initWithPath:aPath flags:openFlags];
    
    ZY_FMDBAutorelease(q);
    
    return q;
}

+ (instancetype)databaseQueueWithURL:(NSURL *)url flags:(int)openFlags {
    return [self databaseQueueWithPath:url.path flags:openFlags];
}

+ (Class)databaseClass {
    return [ZY_FMDatabase class];
}

- (instancetype)initWithURL:(NSURL *)url flags:(int)openFlags vfs:(NSString *)vfsName {
    return [self initWithPath:url.path flags:openFlags vfs:vfsName];
}

- (instancetype)initWithPath:(NSString*)aPath flags:(int)openFlags vfs:(NSString *)vfsName {
    self = [super init];
    
    if (self != nil) {
        
        _db = [[[self class] databaseClass] databaseWithPath:aPath];
        ZY_FMDBRetain(_db);
        
#if SQLITE_VERSION_NUMBER >= 3005000
        BOOL success = [_db openWithFlags:openFlags vfs:vfsName];
#else
        BOOL success = [_db open];
#endif
        if (!success) {
            ZYDebug(@"Could not create database queue for path %@", aPath);
            ZY_FMDBRelease(self);
            return 0x00;
        }
        
        _path = ZY_FMDBReturnRetained(aPath);
        
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.%@", self] UTF8String], NULL);
        dispatch_queue_set_specific(_queue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        _openFlags = openFlags;
        _vfsName = [vfsName copy];
    }
    
    return self;
}

- (instancetype)initWithPath:(NSString *)aPath flags:(int)openFlags {
    return [self initWithPath:aPath flags:openFlags vfs:nil];
}

- (instancetype)initWithURL:(NSURL *)url flags:(int)openFlags {
    return [self initWithPath:url.path flags:openFlags vfs:nil];
}

- (instancetype)initWithURL:(NSURL *)url {
    return [self initWithPath:url.path];
}

- (instancetype)initWithPath:(NSString *)aPath {
    // default flags for sqlite3_open
    return [self initWithPath:aPath flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE vfs:nil];
}

- (instancetype)init {
    return [self initWithPath:nil];
}

- (void)dealloc {
    ZY_FMDBRelease(_db);
    ZY_FMDBRelease(_path);
    ZY_FMDBRelease(_vfsName);
    
    if (_queue) {
        ZY_FMDBDispatchQueueRelease(_queue);
        _queue = 0x00;
    }
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)close {
    ZY_FMDBRetain(self);
    dispatch_sync(_queue, ^() {
        [self->_db close];
        ZY_FMDBRelease(_db);
        self->_db = 0x00;
    });
    ZY_FMDBRelease(self);
}

- (void)interrupt {
    [[self database] interrupt];
}

- (ZY_FMDatabase*)database {
    if (![_db isOpen]) {
        if (!_db) {
           _db = ZY_FMDBReturnRetained([[[self class] databaseClass] databaseWithPath:_path]);
        }
        
#if SQLITE_VERSION_NUMBER >= 3005000
        BOOL success = [_db openWithFlags:_openFlags vfs:_vfsName];
#else
        BOOL success = [_db open];
#endif
        if (!success) {
            ZYDebug(@"ZY_FMDatabaseQueue could not reopen database for path %@", _path);
            ZY_FMDBRelease(_db);
            _db  = 0x00;
            return 0x00;
        }
    }
    
    return _db;
}

- (void)inDatabase:(__attribute__((noescape)) void (^)(ZY_FMDatabase *db))block {
#ifndef NDEBUG
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    ZY_FMDatabaseQueue *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "inDatabase: was called reentrantly on the same queue, which would lead to a deadlock");
#endif
    
    ZY_FMDBRetain(self);
    
    dispatch_sync(_queue, ^() {
        
        ZY_FMDatabase *db = [self database];
        
        block(db);
        
        if ([db hasOpenResultSets]) {
            ZYDebug(@"Warning: there is at least one open result set around after performing [ZY_FMDatabaseQueue inDatabase:]");
            
#if defined(DEBUG) && DEBUG
            NSSet *openSetCopy = ZY_FMDBReturnAutoreleased([[db valueForKey:@"_openResultSets"] copy]);
            for (NSValue *rsInWrappedInATastyValueMeal in openSetCopy) {
                ZY_FMResultSet *rs = (ZY_FMResultSet *)[rsInWrappedInATastyValueMeal pointerValue];
                ZYDebug(@"query: '%@'", [rs query]);
            }
#endif
        }
    });
    
    ZY_FMDBRelease(self);
}

- (void)beginTransaction:(ZY_FMDBTransaction)transaction withBlock:(void (^)(ZY_FMDatabase *db, BOOL *rollback))block {
    ZY_FMDBRetain(self);
    dispatch_sync(_queue, ^() { 
        
        BOOL shouldRollback = NO;

        switch (transaction) {
            case ZY_FMDBTransactionExclusive:
                [[self database] beginTransaction];
                break;
            case ZY_FMDBTransactionDeferred:
                [[self database] beginDeferredTransaction];
                break;
            case ZY_FMDBTransactionImmediate:
                [[self database] beginImmediateTransaction];
                break;
        }
        
        block([self database], &shouldRollback);
        
        if (shouldRollback) {
            [[self database] rollback];
        }
        else {
            [[self database] commit];
        }
    });
    
    ZY_FMDBRelease(self);
}

- (void)inTransaction:(__attribute__((noescape)) void (^)(ZY_FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:ZY_FMDBTransactionExclusive withBlock:block];
}

- (void)inDeferredTransaction:(__attribute__((noescape)) void (^)(ZY_FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:ZY_FMDBTransactionDeferred withBlock:block];
}

- (void)inExclusiveTransaction:(__attribute__((noescape)) void (^)(ZY_FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:ZY_FMDBTransactionExclusive withBlock:block];
}

- (void)inImmediateTransaction:(__attribute__((noescape)) void (^)(ZY_FMDatabase * _Nonnull, BOOL * _Nonnull))block {
    [self beginTransaction:ZY_FMDBTransactionImmediate withBlock:block];
}

- (NSError*)inSavePoint:(__attribute__((noescape)) void (^)(ZY_FMDatabase *db, BOOL *rollback))block {
#if SQLITE_VERSION_NUMBER >= 3007000
    static unsigned long savePointIdx = 0;
    __block NSError *err = 0x00;
    ZY_FMDBRetain(self);
    dispatch_sync(_queue, ^() { 
        
        NSString *name = [NSString stringWithFormat:@"savePoint%ld", savePointIdx++];
        
        BOOL shouldRollback = NO;
        
        if ([[self database] startSavePointWithName:name error:&err]) {
            
            block([self database], &shouldRollback);
            
            if (shouldRollback) {
                // We need to rollback and release this savepoint to remove it
                [[self database] rollbackToSavePointWithName:name error:&err];
            }
            [[self database] releaseSavePointWithName:name error:&err];
            
        }
    });
    ZY_FMDBRelease(self);
    return err;
#else
    NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"ZY_FMDB", nil);
    if (_db.logsErrors) ZYDebug(@"%@", errorMessage);
    return [NSError errorWithDomain:@"ZY_FMDatabase" code:0 userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
#endif
}

- (BOOL)checkpoint:(ZY_FMDBCheckpointMode)mode error:(NSError * __autoreleasing *)error
{
    return [self checkpoint:mode name:nil logFrameCount:NULL checkpointCount:NULL error:error];
}

- (BOOL)checkpoint:(ZY_FMDBCheckpointMode)mode name:(NSString *)name error:(NSError * __autoreleasing *)error
{
    return [self checkpoint:mode name:name logFrameCount:NULL checkpointCount:NULL error:error];
}

- (BOOL)checkpoint:(ZY_FMDBCheckpointMode)mode name:(NSString *)name logFrameCount:(int * _Nullable)logFrameCount checkpointCount:(int * _Nullable)checkpointCount error:(NSError * __autoreleasing _Nullable * _Nullable)error
{
    __block BOOL result;
    __block NSError *blockError;
    
    ZY_FMDBRetain(self);
    dispatch_sync(_queue, ^() {
        result = [self.database checkpoint:mode name:name logFrameCount:logFrameCount checkpointCount:checkpointCount error:&blockError];
    });
    ZY_FMDBRelease(self);
    
    if (error) {
        *error = blockError;
    }
    return result;
}

@end
