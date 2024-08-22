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
@implementation FTRequestMultipartFormBody{
    NSNumber *kTrue, *kFalse;
}

-(instancetype)init{
    self = [super init];
    if(self){
        _boundary = FTCreateMultipartFormBoundary();
        _body = [[NSMutableData alloc]init];
        kTrue = @YES;
        kFalse = @NO;
    }
    return self;
}
-(NSString *)boundary{
    return _boundary;
}
- (NSData *)newlineByte{
    return [kFTMultipartFormLF dataUsingEncoding:NSUTF8StringEncoding];
}
- (void)addFormField:(NSString *)name value:(id)value {
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";%@%@", name,kFTMultipartFormCRLF,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
    if([value isKindOfClass:NSString.class]){
        [self.body appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
    }else if([value isKindOfClass:NSNumber.class]){
        NSNumber *number = (NSNumber *)value;
        if (number == kTrue || number == kFalse){
            if([number boolValue]){
                [self.body appendBytes:"true" length:4];
            }else{
                [self.body appendBytes:"false" length:5];
            }
        }else{
            const char *objcType = [number objCType];
            char num[128];
            int len;
            
            switch (objcType[0]) {
                case 'c': case 'i': case 's': case 'l': case 'q':
                    len = snprintf(num, sizeof num, "%lld", [number longLongValue]);
                    break;
                case 'C': case 'I': case 'S': case 'L': case 'Q':
                    len = snprintf(num, sizeof num, "%llu", [number unsignedLongLongValue]);
                    break;
                case 'f': case 'd': default: {
                    len = snprintf(num, sizeof num, "%.17f", [number doubleValue]);
                    break;
                }
            }
            [self.body appendBytes:num length:(NSUInteger)len];
        }
    }else if([value isKindOfClass:NSData.class]){
        [self.body appendData:value];
    }
    [self.body appendData:[kFTMultipartFormCRLF dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void)addFormData:(NSString *)name filename:(NSString *)fileName data:(NSData *)data mimeType:(NSString *)mimeType{
    [self.body appendData:[FTMultipartFormInitialBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding]];
    [self.body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", name,fileName,kFTMultipartFormCRLF] dataUsingEncoding:NSUTF8StringEncoding]];
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
