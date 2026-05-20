//
//  FTRecordModel.h
//  FTMobileAgent
//
//  Created by hulilei on 2019/11/28.
//  Copyright © 2019 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

/// Data storage model
@interface FTRecordModel : NSObject

/// Time when data was collected (nanosecond timestamp)
@property (nonatomic, assign) long long tm;
/// Recorded operation data
@property (nonatomic, copy) NSString *data;
/// Data type, \RUM\Logging
@property (nonatomic, copy) NSString *op;
/// Whether this data has been checked by SDK remote DataFilter before being stored.
@property (nonatomic, assign) BOOL remoteFilterChecked;

/// Store database generated primary key
@property (nonatomic, copy) NSString * _id;

/// Initialization method
/// - Parameters:
///   - source: data source
///   - op: data type
///   - tags: tag type data
///   - fields: field type data
///   - tm: time when data was collected (nanosecond timestamp)
-(instancetype)initWithSource:(NSString *)source op:(NSString *)op tags:(nullable NSDictionary *)tags fields:(nullable NSDictionary *)fields tm:(long long)tm;
@end

NS_ASSUME_NONNULL_END
