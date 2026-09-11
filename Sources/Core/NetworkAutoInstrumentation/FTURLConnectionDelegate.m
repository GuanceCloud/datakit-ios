//
//  FTURLConnectionDelegate.m
//  FTMobileSDK
//

#import "FTURLConnectionDelegate.h"
#import "FTURLConnectionHandler.h"
#import "FTURLConnectionInstrumentation.h"
#import "FTURLConnectionDelegateInstrumentor.h"
#import "FTInnerLog.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation FTURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            FTURLConnectionHandler *handler = [FTURLConnectionInstrumentation handlerForConnection:connection];
            [handler.instrumentation handler:handler didReachTerminalWithResponse:nil error:error];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection failure observation exception: %@", exception);
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            FTURLConnectionHandler *handler = [FTURLConnectionInstrumentation handlerForConnection:connection];
            return [handler.instrumentation handler:handler redirectedRequest:request response:response] ?: request;
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection redirect observation exception: %@", exception);
    }
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            [[FTURLConnectionInstrumentation handlerForConnection:connection] didReceiveResponse:response];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection response observation exception: %@", exception);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            [[FTURLConnectionInstrumentation handlerForConnection:connection] didReceiveData:data];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection data observation exception: %@", exception);
    }
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            [[FTURLConnectionInstrumentation handlerForConnection:connection] didSendBodyDataWithTotalBytesWritten:totalBytesWritten];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection upload observation exception: %@", exception);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    @try {
        if ([FTURLConnectionDelegateInstrumentor shouldObserveDelegate:self connection:connection selector:_cmd]) {
            FTURLConnectionHandler *handler = [FTURLConnectionInstrumentation handlerForConnection:connection];
            [handler.instrumentation handler:handler didReachTerminalWithResponse:nil error:nil];
        }
    } @catch (NSException *exception) {
        FTInnerLogError(@"NSURLConnection completion observation exception: %@", exception);
    }
}

@end

#pragma clang diagnostic pop
