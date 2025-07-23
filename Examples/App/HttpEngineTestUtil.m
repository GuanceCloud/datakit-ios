//
//  HttpEngineTestUtil.m
//  App
//
//  Created by hulilei on 2022/9/26.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

#import "HttpEngineTestUtil.h"
#import "FTExternalDataManager.h"
// id <NSURLSessionDelegate>)delegate directly inherit FTURLSessionDelegate example
@interface InstrumentationInheritTestClass:FTURLSessionDelegate
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) Completion completion;
@end
@implementation InstrumentationInheritTestClass
-(instancetype)initWithCompletion:(Completion)completion{
    self = [super init];
    if(self){
        _completion = completion;
    }
    return self;
}
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics{
    // Must call parent class method
    [super URLSession:session task:task didFinishCollectingMetrics:metrics];
    // User's own logic
    // ......
    if(self.completion){
        self.completion();
    }

}
@end

/*
 * When session's delegate is not FTURLSessionDelegate, need to follow FTURLSessionDelegateProviding protocol, implement - (nonnull FTURLSessionDelegate *)ftURLSessionDelegate method
 * And in delegate method:
 * - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
 * - (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
 * Inside, call FTURLSessionDelegate's corresponding method for SDK data collection.
 */
@interface InstrumentationPropertyTestClass:NSObject<NSURLSessionDataDelegate,FTURLSessionDelegateProviding>
@property (nonatomic, copy) Completion completion;
@end
@implementation InstrumentationPropertyTestClass
@synthesize ftURLSessionDelegate = _ftURLSessionDelegate;
-(FTURLSessionDelegate *)ftURLSessionDelegate{
    if (!_ftURLSessionDelegate) {
        _ftURLSessionDelegate = [[FTURLSessionDelegate alloc]init];
    }
    return _ftURLSessionDelegate;
}
-(instancetype)initWithCompletion:(Completion)completion{
    self = [super init];
    if(self){
        _completion = completion;
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
    [self.ftURLSessionDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    if(self.completion){
        self.completion();
    }
}

@end


@interface HttpEngineTestUtil ()<NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, copy) Completion completion;

@end
@implementation HttpEngineTestUtil
- (instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type completion:(nonnull Completion)completion {
    return [self initWithSessionInstrumentationType:type provider:nil requestInterceptor:nil traceInterceptor:nil completion:completion];
}

-(instancetype)initWithSessionInstrumentationType:(TestSessionInstrumentationType)type
                                         provider:(nullable ResourcePropertyProvider)provider
                               requestInterceptor:(nullable RequestInterceptor)requestInterceptor
                                 traceInterceptor:(nullable TraceInterceptor)traceInterceptor
                                       completion:(Completion)completion
{
    self = [super init];
    if(self){
        _completion = completion;
        [self session:type provider:provider requestInterceptor:requestInterceptor traceInterceptor:traceInterceptor completion:completion];
    }
    return self;
}
- (void)session:(TestSessionInstrumentationType)type provider:(ResourcePropertyProvider)provider
requestInterceptor:(RequestInterceptor)requestInterceptor
traceInterceptor:(TraceInterceptor)traceInterceptor
     completion:(Completion)completion
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
            InstrumentationInheritTestClass *ftDelegate = [[InstrumentationInheritTestClass alloc]initWithCompletion:completion];
            ftDelegate.provider = provider;
            ftDelegate.requestInterceptor = requestInterceptor;
            ftDelegate.traceInterceptor = traceInterceptor;
            delegate = ftDelegate;
            break;
        }
        case InstrumentationProperty: {
            InstrumentationPropertyTestClass *ftDelegate = [[InstrumentationPropertyTestClass alloc]initWithCompletion:completion];
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
- (NSURLSessionTask *)network{
    NSString *urlStr = [[NSProcessInfo processInfo] environment][@"TRACE_URL"];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
    return task;
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
    if(self.completion){
        self.completion();
    }
}
-(void)dealloc{
    [_session invalidateAndCancel];
}
@end
