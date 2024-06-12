//
//  FTRequestImageBody.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTRequestImageBody.h"
static NSString * const kFTMultipartFormCRLF = @"\r\n";
static NSString * FTCreateMultipartFormBoundary(void) {
    return [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
}
static inline NSString * FTMultipartFormInitialBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"--%@%@", boundary, kFTMultipartFormCRLF];
}
static inline NSString * FTMultipartFormFinalBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"--%@--%@", boundary, kFTMultipartFormCRLF];
}
@interface FTRequestImageBody()
@property (nonatomic, strong) NSMutableData *body;
@end
@implementation FTRequestImageBody

-(instancetype)init{
    self = [super init];
    if(self){
        _boundary = FTCreateMultipartFormBoundary();
        _body = [[NSMutableData alloc]init];
    }
    return self;
}
-(NSString *)boundary{
    return _boundary;
}
- (void)appendDataWithFormFiled:(NSString *)value
                          name:(NSString *)name{
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";%@%@", name,kFTMultipartFormCRLF,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
}
- (void)appendDataWithFormData:(NSData *)data
                          name:(NSString *)name{
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"segment\"; filename=\"%@\"%@", name,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Type: application/octet-stream %@",kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:data];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
}
-(NSData *)getRequestBodyWithImageDatas:(NSArray *)datas parameters:(NSDictionary *)parameters{
    if(datas&&parameters){
        //添加image data
        NSString *path = [datas firstObject];
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];
        [self appendDataWithFormData:data name:name];
        [self appendDataWithFormFiled:[NSString stringWithFormat:@"%lu",(unsigned long)data.length] name:@"raw_segment_size"];
        
        //已知 parameters value 类型均为 NSString
        NSString *key;
        NSEnumerator *enumer = [parameters.allKeys objectEnumerator];
        while ((key = enumer.nextObject)!=nil) {
            [self appendDataWithFormFiled:[NSString stringWithFormat:@"%@",parameters[key]] name:key];
        }
        [self.body appendData:[FTMultipartFormFinalBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return self.body;
}
@end
