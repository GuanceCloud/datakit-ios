//
//  FTFile.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FTFileProtocol <NSObject>
@property (nonatomic, strong) NSURL *url;
- (NSDate *)modifiedAt;
@end

@protocol  FTReadableFile <NSObject>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSURL *url;
- (NSInputStream *)stream;
- (void)deleteFile;
@end

@protocol FTWritableFile <NSObject>
@property (nonatomic, copy) NSString *name;

- (long long)size;
- (void)append:(NSData *)data;

@end

@interface FTFile : NSObject<FTReadableFile,FTWritableFile>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *fileCreationDate;
-(instancetype)initWithUrl:(NSURL *)url;
- (void)write:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
