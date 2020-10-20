//
//  FTJSONUtil.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//

#import "FTJSONUtil.h"
#import "FTLog.h"
#import "FTJsonWriter.h"
@interface FTJSONUtil ()<FTJsonWriterDelegate>
@property (nonatomic, copy) NSString *error;
@property (nonatomic, strong) NSMutableData *acc;
@end
@implementation FTJSONUtil

/**
 *  @abstract
 *  把一个Object转成JsonData
 *
 *  @param obj 要转化的字典对象Object
 *
 *  @return 转化后得到的DATA
 */
- (NSData *)JSONSerializeDictObject:(NSDictionary *)obj {
    self.error = nil;

    self.acc = [[NSMutableData alloc] initWithCapacity:8096u];

    FTJsonWriter *streamWriter = [FTJsonWriter writerWithDelegate:self];

    if ([streamWriter writeObject:obj])
        return self.acc;

    self.error = streamWriter.error;
    return nil;
}

- (void)writer:(FTJsonWriter *)writer appendBytes:(const void *)bytes length:(NSUInteger)length {
    [self.acc appendBytes:bytes length:length];
}

@end
