//
//  HttpEngineTestUtil.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "HttpEngineTestUtil.h"
#import "FTExternalDataManager.h"
// id <NSURLSessionDelegate>)delegate 直接继承 FTURLSessionDelegate 示例
@interface InstrumentationInheritTestClass:FTURLSessionDelegate
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) XCTestExpectation *expectation;
@end
@implementation InstrumentationInheritTestClass
-(instancetype)initWithExpectation:(XCTestExpectation *)expectation{
    self = [super init];
    if(self){
        self.expectation = expectation;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    // 一定要调用 父类 方法
    [super URLSession:session task:task didFinishCollectingMetrics:metrics];
    // 用户自己的逻辑
    // ......
    [self.expectation fulfill];

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
@interface InstrumentationPropertyTestClass:NSObject<NSURLSessionDataDelegate,FTURLSessionDelegateProviding>
@property (nonatomic, strong) XCTestExpectation *expectation;
@end
@implementation InstrumentationPropertyTestClass
@synthesize ftURLSessionDelegate = _ftURLSessionDelegate;
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    if (!_ftURLSessionDelegate) {
        _ftURLSessionDelegate = [[FTURLSessionDelegate alloc]init];
    }
    return _ftURLSessionDelegate;
}
-(instancetype)initWithExpectation:(XCTestExpectation *)expectation{
    self = [super init];
    if(self){
        self.expectation = expectation;
    }
    return self;
}
 
-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    [self.ftURLSessionDelegate URLSession:session dataTask:dataTask didReceiveData:data];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    [self.ftURLSessionDelegate URLSession:session task:task didCompleteWithError:error];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self.expectation fulfill];
    [self.ftURLSessionDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
}

@end


@interface HttpEngineTestUtil ()<NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) XCTestExpectation *expectation;

@end
@implementation HttpEngineTestUtil
- (instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type expectation:(nonnull XCTestExpectation *)expectation {
    return [self initWithSessionInstrumentationType:type expectation:expectation provider:nil requestInterceptor:nil traceInterceptor:nil];
}

-(instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type expectation:( XCTestExpectation *)expectation provider:(ResourcePropertyProvider)provider requestInterceptor:(RequestInterceptor)requestInterceptor
                                 traceInterceptor:(TraceInterceptor)traceInterceptor
{
    self = [super init];
    if(self){
        [self initSession:type expectation:expectation provider:provider requestInterceptor:requestInterceptor traceInterceptor:traceInterceptor];
    }
    return self;
}
- (void)initSession:(TestSessionInstrumentationType)type expectation:( XCTestExpectation *)expectation provider:(ResourcePropertyProvider)provider requestInterceptor:(RequestInterceptor)requestInterceptor
   traceInterceptor:(TraceInterceptor)traceInterceptor
{
    id<NSURLSessionDelegate> delegate;

    switch (type) {
        case InstrumentationDirect:{
            FTURLSessionDelegate *ftDelegate = [[FTURLSessionDelegate alloc]init];
            ftDelegate.provider = provider;
            ftDelegate.requestInterceptor = requestInterceptor;
            ftDelegate.traceInterceptor = traceInterceptor;
            delegate = ftDelegate;
        }
            break;
            
        case InstrumentationInherit: {
            InstrumentationInheritTestClass *ftDelegate = [[InstrumentationInheritTestClass alloc]initWithExpectation:expectation];
            ftDelegate.provider = provider;
            ftDelegate.requestInterceptor = requestInterceptor;
            ftDelegate.traceInterceptor = traceInterceptor;
            delegate = ftDelegate;
            break;
        }
        case InstrumentationProperty: {
            InstrumentationPropertyTestClass *ftDelegate = [[InstrumentationPropertyTestClass alloc]initWithExpectation:expectation];
            ftDelegate.ftURLSessionDelegate.provider = provider;
            ftDelegate.ftURLSessionDelegate.requestInterceptor = requestInterceptor;
            ftDelegate.ftURLSessionDelegate.traceInterceptor = traceInterceptor;
            delegate = ftDelegate;
            break;
        }
    }
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];

    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
}
- (void)network:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = [@"111" dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPMethod = @"POST";
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(completionHandler){
            completionHandler(data,response,error);
        }
    }];
    [task resume];
}
- (void)network{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}
- (void)urlNetwork:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(completionHandler){
            completionHandler(data,response,error);
        }
    }];
    [task resume];
}
- (void)urlNetwork{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSessionTask *task = [self.session dataTaskWithURL:url];
    [task resume];
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    [self.expectation fulfill];
}
-(void)dealloc{
    [_session invalidateAndCancel];
}
@end
