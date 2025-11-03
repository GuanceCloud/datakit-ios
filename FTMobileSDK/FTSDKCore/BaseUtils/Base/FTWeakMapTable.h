//
//  FTWeakMapTable.h
//  FTMobileSDK
//
//  Created by hulilei on 2025/10/27.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Resolves the object deallocation issue of NSMapTable weakToStrongObjectsMapTable
/// Thread-safe for read and write operations
@interface FTWeakMapTable<KeyType, ObjectType> : NSObject

/// Adds a key-value pair (write operation)
- (void)setObject:(nullable id)object forKey:(nullable id)key;

/// Retrieves the value by key (read operation)
- (nullable id)objectForKey:(nullable id)key;

/// Removes the entry for the specified key (write operation)
- (void)removeObjectForKey:(nullable id)key;

/// Thread-safely enumerates all valid key-value pairs and processes them in the block (supports modifying the dictionary within the block)
/// @param block Enumeration callback with parameters: original key (non-wrapper class), corresponding value, and a flag to stop enumeration
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id object, BOOL *stop))block;

/// Removes all key-value pairs from the dictionary (thread-safe)
- (void)removeAllObjects;

/// Cleans up invalid entries (write operation)
- (void)pruneInvalidEntries;
@end

NS_ASSUME_NONNULL_END
