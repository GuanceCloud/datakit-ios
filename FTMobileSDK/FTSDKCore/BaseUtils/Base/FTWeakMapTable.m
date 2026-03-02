//
//  FTWeakMapTable.m
//  FTMobileSDK
//
//  Created by hulilei on 2025/10/27.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import "FTWeakMapTable.h"
#import "FTLog+Private.h"
#import <pthread.h>
/// Weak reference wrapper class, used to wrap keys that need weak references
@interface WeakWrapper : NSObject<NSCopying>

/// Weakly referenced key object (the actual key being wrapped)
@property (nonatomic, weak, readonly) id object;

/// Initialize the wrapper class
/// @param object The key object that needs a weak reference (must implement hash and isEqual methods)
- (instancetype)initWithObject:(id)object;

@end
@implementation WeakWrapper{
    __weak id _object;
    NSUInteger _hash;
}

- (instancetype)initWithObject:(id)object {
    self = [super init];
    if (self) {
        _object = object; // Weak reference, automatically becomes nil after object is released
        _hash = [object hash];
    }
    return self;
}

- (NSUInteger)hash
{
    return _hash;
}

/// Override the isEqual method to compare based on the wrapped object (ensure equality judgment when used as a dictionary key)
- (BOOL)isEqual:(id)other {
    if (self == other) return YES;
    if (![other isKindOfClass:[WeakWrapper class]]) return NO;
    WeakWrapper *otherWrapper = (WeakWrapper *)other;
    return self.object == otherWrapper.object || [self.object isEqual:otherWrapper.object];
}
-(instancetype)copyWithZone:(NSZone *)zone{
    
    return [[[WeakWrapper class] allocWithZone:zone] initWithObject:self.object];
}
@end

@implementation FTWeakMapTable{
    NSMutableDictionary<WeakWrapper *, id> *_dictionary; // Storage: key=WeakWrapper, value=strong reference object
    pthread_rwlock_t _rwlock; // Read-write lock
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dictionary = [NSMutableDictionary dictionary];
        // Initialize the read-write lock (non-recursive to avoid deadlock risks)
        int error = pthread_rwlock_init(&_rwlock, NULL);
        if (error != 0) {
            FTInnerLogError(@"Read-write lock initialization failed, error code: %d", error);
        }
    }
    return self;
}
#pragma mark - Read operations (shared lock)

- (id)objectForKey:(id)key {
    if (!key) return nil;
    
    // Add read lock (shared lock, allowing multiple read operations simultaneously)
    int error = pthread_rwlock_rdlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire read lock, error code: %d", error);
        return nil;
    }
    
    @try {
        [self pruneInvalidEntriesWithoutLock];

        // Create a temporary wrapper class with the same key for lookup
        WeakWrapper *wrapper = [[WeakWrapper alloc] initWithObject:key];
        id value = _dictionary[wrapper];
        return value;
    } @finally {
        // Release the read lock
        pthread_rwlock_unlock(&_rwlock);
    }
}

#pragma mark - Write operations (exclusive lock)

- (void)setObject:(id)object forKey:(id)key {
    if (!key || !object) return;
    
    // Add write lock (exclusive lock, allowing only one write operation at a time)
    int error = pthread_rwlock_wrlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire write lock, error code: %d", error);
        return;
    }
    
    @try {
        // Wrap the key with WeakWrapper and store it in the dictionary
        WeakWrapper *wrapper = [[WeakWrapper alloc] initWithObject:key];
        _dictionary[wrapper] = object;
        // Clean up invalid entries after addition (done within the write operation to avoid separate locking)
        [self pruneInvalidEntriesWithoutLock];
    } @finally {
        // Release the write lock
        pthread_rwlock_unlock(&_rwlock);
    }
}

- (void)removeObjectForKey:(id)key {
    if (!key) return;
    
    // Add write lock
    int error = pthread_rwlock_wrlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire write lock, error code: %d", error);
        return;
    }
    
    @try {
        WeakWrapper *wrapper = [[WeakWrapper alloc] initWithObject:key];
        [_dictionary removeObjectForKey:wrapper];
    } @finally {
        pthread_rwlock_unlock(&_rwlock);
    }
}
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id object, BOOL *stop))block {
    if (!block) return;
    
    // Add write lock (ensure atomicity of traversal and operations in the block, supporting dictionary modification in the block)
    int error = pthread_rwlock_wrlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire write lock, error code: %d", error);
        return;
    }
    
    @try {
        // First clean up invalid entries (avoid traversing released keys)
        [self pruneInvalidEntriesWithoutLock];
        
        // Traverse all valid key-value pairs (keys are WeakWrapper, need to extract the original object)
        BOOL stop = NO;
        for (WeakWrapper *wrapper in _dictionary.allKeys) {
            id originalKey = wrapper.object; // Original key (confirmed non-nil because it has been cleaned up)
            id value = _dictionary[wrapper];
            
            // Execute the block, passing the original key, value, and stop flag
            block(originalKey, value, &stop);
            if (stop) break; // Respond to stop traversal
        }
    } @finally {
        // Release the write lock
        pthread_rwlock_unlock(&_rwlock);
    }
}

- (void)removeAllObjects {
    // Add write lock (exclusive lock, ensuring the clearing operation is not interfered by other threads)
    int error = pthread_rwlock_wrlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire write lock (removeAllObjects), error code: %d", error);
        return;
    }
    
    @try {
        // Directly clear all key-value pairs stored internally (including valid and invalid entries)
        [_dictionary removeAllObjects];
    } @finally {
        // Release the write lock
        pthread_rwlock_unlock(&_rwlock);
    }
}

- (void)pruneInvalidEntries {
    // Add write lock (cleanup is a write operation and needs to be exclusive)
    int error = pthread_rwlock_wrlock(&_rwlock);
    if (error != 0) {
        FTInnerLogError(@"Failed to acquire write lock, error code: %d", error);
        return;
    }
    
    @try {
        [self pruneInvalidEntriesWithoutLock];
    } @finally {
        pthread_rwlock_unlock(&_rwlock);
    }
}

/// Internal cleanup logic (only called when the write lock has been acquired)
- (void)pruneInvalidEntriesWithoutLock {
    NSMutableArray<WeakWrapper *> *invalidWrappers = [NSMutableArray array];
    
    for (WeakWrapper *wrapper in _dictionary.allKeys) {
        if (!wrapper.object) { // Key has been released
            [invalidWrappers addObject:wrapper];
        }
    }
    
    for (WeakWrapper *wrapper in invalidWrappers) {
        [_dictionary removeObjectForKey:wrapper];
    }
}

- (void)dealloc {
    // Destroy the read-write lock and release resources
    pthread_rwlock_destroy(&_rwlock);
}
@end
