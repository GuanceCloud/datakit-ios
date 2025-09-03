//
//  FTDirectory.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class FTFile;
@interface FTDirectory : NSObject
@property (nonatomic, strong, readonly) NSURL *url;

-(instancetype)initWithUrl:(NSURL *)url;
-(instancetype)initWithSubdirectoryPath:(NSString *)path;

- (NSArray<FTFile*>*)files;
- (nullable FTFile *)createFile:(NSString *)fileName;
- (BOOL)hasFileWithName:(NSString *)fileName;
- (nullable FTFile *)fileWithName:(NSString *)fileName;
- (nullable FTDirectory *)createSubdirectoryWithPath:(NSString *)path;
- (void)deleteAllFiles;
@end

NS_ASSUME_NONNULL_END
