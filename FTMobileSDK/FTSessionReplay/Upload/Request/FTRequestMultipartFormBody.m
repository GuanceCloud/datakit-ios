//
//  FTRequestImageBody.m
//  FTMobileAgent
//
//  Created by hulilei on 2023/1/6.
//  Copyright © 2023 DataFlux-cn. All rights reserved.
//

#import "FTRequestMultipartFormBody.h"
static NSString * const kFTMultipartFormCRLF = @"\r\n";
static NSString * const kFTMultipartFormLF = @"\n";
static NSString * FTCreateMultipartFormBoundary(void) {
    return [NSString stringWithFormat:@"Boundary+%08X%08X", arc4random(), arc4random()];
}
static inline NSString * FTMultipartFormInitialBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"--%@%@", boundary, kFTMultipartFormCRLF];
}
static inline NSString * FTMultipartFormFinalBoundary(NSString *boundary) {
    return [NSString stringWithFormat:@"--%@--%@", boundary, kFTMultipartFormCRLF];
}
@interface FTRequestMultipartFormBody()
@property (nonatomic, strong) NSMutableData *body;
@end
@implementation FTRequestMultipartFormBody

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
- (NSData *)newlineByte{
    return [kFTMultipartFormLF dataUsingEncoding:NSUTF8StringEncoding];
}
- (void)addFormField:(NSString *)name value:(nonnull NSString *)value {
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";%@%@", name,kFTMultipartFormCRLF,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void)addFormData:(NSString *)name filename:(NSString *)filename data:(NSData *)data mimeType:(NSString *)mimeType{
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", name,filename,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Type: %@%@", mimeType,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:data];
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSData *)build{
    [self.body appendData:[FTMultipartFormFinalBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *data = self.body;
    [self updateBody];
    return data;
}
- (void)updateBody{
    self.boundary = FTCreateMultipartFormBoundary();
    self.body = [[NSMutableData alloc]init];
}
@end
