//
//  HttpEngine.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "HttpEngine.h"
// id <NSURLSessionDelegate>)delegate 直接继承 FTURLSessionDelegate 示例
@interface InstrumentationInheritClass:FTURLSessionDelegate
@property (nonatomic, strong) NSURLSession *session;
@end
@implementation InstrumentationInheritClass
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    // 一定要调用 父类 方法
    [super URLSession:session task:task didFinishCollectingMetrics:metrics];
    // 用户自己的逻辑
    // ......
}
@end

/**
 * session 的 delegate 不为 FTURLSessionDelegate 时，需要遵循 FTURLSessionDelegateProviding 协议，实现 - (nonnull FTURLSessionDelegate *)ftURLSessionDelegate 方法
 * 并在 delegate 方法：
 * - (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 didReceiveData:(NSData *)data;
 * - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 didCompleteWithError:(nullable NSError *)error;
 * - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0));
 * 内部，调用 FTURLSessionDelegate 的对应方法，以便于 SDK 进行数据采集。
 *
 */
@interface InstrumentationPropertyClass:NSObject<NSURLSessionDataDelegate>
@property (nonatomic, strong) FTURLSessionDelegate *sessionDelegate;
@end
@implementation InstrumentationPropertyClass
-(FTURLSessionDelegate *)sessionDelegate{
    if(!_sessionDelegate){
        _sessionDelegate = [[FTURLSessionDelegate alloc]init];
    }
    return _sessionDelegate;
}
- (nonnull FTURLSessionDelegate *)ftURLSessionDelegate {
    return self.sessionDelegate;
}
 
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.sessionDelegate URLSession:session dataTask:dataTask didReceiveData:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.sessionDelegate URLSession:session task:task didCompleteWithError:error];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self.sessionDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
}
@end


@interface HttpEngine ()<NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end
@implementation HttpEngine
-(instancetype)initWithSessionInstrumentationType:(FTSessionInstrumentationType)type{
    self = [super init];
    if(self){
        [self initSession:type];
    }
    return self;
}
- (void)initSession:(FTSessionInstrumentationType)type{
    id<NSURLSessionDelegate> delegate;
    switch (type) {
        case InstrumentationDirect:{
            delegate = [[FTURLSessionDelegate alloc]init];
        }
            break;
            
        case InstrumentationInherit: {
            delegate = [[InstrumentationInheritClass alloc]init];
            break;
        }
        case InstrumentationProperty: {
            delegate = [[InstrumentationPropertyClass alloc]init];
            break;
        }
    }
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];

    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
}
- (void)network:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(completionHandler){
            completionHandler(data,response,error);
        }
    }];
    [task resume];
}
@end
