//
//  FTJsonWriter.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/10/20.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTJsonWriter;
@protocol FTJsonWriterDelegate

- (void)writer:(FTJsonWriter *)writer appendBytes:(const void *)bytes length:(NSUInteger)length;

@end
@interface FTJsonWriter : NSObject{
    NSMutableDictionary *cache;
}
+ (id)writerWithDelegate:(id<FTJsonWriterDelegate>)delegate;
@property (nonatomic, copy) NSString *error;

- (BOOL)writeObject:(NSDictionary*)dict;
@end
@interface FTJsonWriter (Private)
- (BOOL)writeValue:(id)v;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
