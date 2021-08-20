//
//  FTNetworkManager.m
//  FTMacOSSDK
//
//  Created by 胡蕾蕾 on 2021/8/2.
//  Copyright © 2021 DataFlux-cn. All rights reserved.
//

#import "FTNetworkManager.h"

@interface FTNetworkManager()
@property (nonatomic, strong) NSURLSession *session;
@end
@implementation FTNetworkManager
+ (instancetype)sharedInstance {
    return [self shareManagerURLSession:[NSURLSession sharedSession]];
}
+ (instancetype)shareManagerURLSession:(NSURLSession *)session{
    static FTNetworkManager *manger;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manger = [[FTNetworkManager alloc]init];
        manger.session = session;
    });
    return manger;
}
- (NSURLSessionDataTask *)realSendRequest:(id<FTRequestProtocol>)request
                           completion:(void(^_Nullable)(NSHTTPURLResponse * _Nonnull httpResponse,
                             NSData * _Nullable data,
                             NSError * _Nullable error))callback{
    
    NSURLRequest *urlRequest = [self createRequest:request];
    
    NSURLSessionDataTask  *task =
    
    [self.session dataTaskWithRequest:urlRequest
                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            callback(httpResponse,data,error);
        });
    }];
    
    [task resume];
    
    return task;
}
- (NSURLRequest *)createRequest:(id<FTRequestProtocol>)requestObject{
    NSURL *url = requestObject.absoluteURL;
    if (!url) {
        return nil;
    }
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc]initWithURL:requestObject.absoluteURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    if([requestObject respondsToSelector:@selector(adaptedRequest:)]){
        urlRequest = [requestObject adaptedRequest:urlRequest];
    }
    return urlRequest;
}

- (void)sendRequest:(id<FTRequestProtocol>  _Nonnull)request
         completion:(void(^_Nullable)(NSHTTPURLResponse * _Nonnull httpResponse,
                                      NSData * _Nullable data,
                                      NSError * _Nullable error))callback{
    [self realSendRequest:request completion:callback];
}
@end
