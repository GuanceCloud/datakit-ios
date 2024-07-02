//
//  FTFile.m
//  FTMobileSDK
//
//  Created by hulilei on 2024/6/21.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#import "FTFile.h"
@interface FTFile()

@end
@implementation FTFile
-(instancetype)initWithUrl:(NSURL *)url{
    self = [super init];
    if(self){
        _url = url;
        _name = [url lastPathComponent];
    }
    return self;
}
- (NSDate *)modifiedAt{
    NSError *error;
    NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.url.path error:&error] fileCreationDate];
    return date;
}
- (void)append:(NSData *)data{
    NSError *error;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:self.url error:&error];
    if (@available(macOS 10.15, iOS 13.0, *)) {
        __autoreleasing NSError *error = nil;
        [fileHandle seekToEndReturningOffset:nil error:&error];
        [fileHandle writeData:data error:&error];
        [fileHandle closeAndReturnError:&error];
    } else {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];
        [fileHandle closeFile];
    }
}
- (void)write:(NSData *)data{
    NSError *error;
    [data writeToURL:self.url options:NSDataWritingAtomic error:&error];
}
- (NSInputStream *)stream{
    NSInputStream *stream = [NSInputStream inputStreamWithURL:self.url];
    return stream;
}
- (long long)size{
    NSError *error;
    long long size = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.url.path error:&error] fileSize];
    return size;
}
- (void)deleteFile{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:self.url error:&error];
}
-(NSDate *)fileCreationDate{
    if(!_fileCreationDate){
        NSTimeInterval time = self.name?[self.name doubleValue]/1000:0;
        _fileCreationDate = [NSDate dateWithTimeIntervalSinceReferenceDate:time];
    }
    return _fileCreationDate;
}
@end
