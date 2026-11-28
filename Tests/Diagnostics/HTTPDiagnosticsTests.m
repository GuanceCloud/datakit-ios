#import <Foundation/Foundation.h>
#import "FTHTTPClient.h"
#import "FTDiagnostics.h"
#define CHECK(x) do { if(!(x)){fprintf(stderr,"Failed line %d: %s\n",__LINE__,#x);abort();} }while(0)
NSString * const FT_HTTP_HEADER_X_SDK_INTERNAL_REQUEST=@"X-FT-SDK-Internal-Request";
@interface DiagnosticLoggingRequest : NSObject <FTRequestProtocol>
@property (nonatomic, strong) NSURL *absoluteURL;
@end
@implementation DiagnosticLoggingRequest
- (NSString *)path{return @"/";}
- (NSString *)contentType{return @"text/plain";}
- (NSString *)httpMethod{return @"POST";}
- (NSString *)serialNumber{return nil;}
- (BOOL)enableDataIntegerCompatible{return NO;}
- (NSString *)userAgent{return @"diagnostic-test";}
- (FTSerialNumberGenerator *)classSerialGenerator{return nil;}
- (NSMutableURLRequest *)adaptedRequest:(NSMutableURLRequest *)r {r.HTTPMethod=@"POST";r.HTTPBody=[@"hello" dataUsingEncoding:NSUTF8StringEncoding];return r;}
@end
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=2)return 2;
    NSError *error=nil;
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    NSURL *export=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    FTDiagnostics *diagnostics=[[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];
    CHECK(diagnostics);
    NSString *session=[diagnostics start:&error];CHECK(session);
    DiagnosticLoggingRequest *request=[DiagnosticLoggingRequest new];request.absoluteURL=[NSURL URLWithString:@(argv[1])];
    FTHTTPClient *client=[FTHTTPClient new];dispatch_semaphore_t done=dispatch_semaphore_create(0);
    __block BOOL success=NO;
    [client sendRequest:request completion:^(NSHTTPURLResponse *r,NSData *data,NSError *error){success=!error && r.statusCode==200 && data.length==2;dispatch_semaphore_signal(done);}];
    if(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,20*NSEC_PER_SEC)))return 4;
    NSDictionary *summary=[diagnostics stop:&error];CHECK(summary);
    NSArray *records=[diagnostics records:session offset:0 limit:100 error:&error];CHECK(records.count==2);
    NSDictionary *start=records[0],*end=records[1];
    CHECK([start[@"event_type"] isEqual:@"upload_start"]);
    CHECK([end[@"event_type"] isEqual:@"upload_end"]);
    CHECK([start[@"attempt_id"] isEqual:end[@"attempt_id"]]);
    CHECK([end[@"session_id"] isEqual:session]);
    CHECK([end[@"byte_availability"] isEqual:@"observed"]);
    CHECK([end[@"status_code"] intValue]==200);
    CHECK([end[@"duration_ms"] doubleValue]>=0);
    if(!success || [end[@"request_body_bytes"] longLongValue]!=5 || [end[@"response_body_bytes"] longLongValue]!=2){NSLog(@"HTTP diagnostics mismatch %@",end);return 5;}
    NSDictionary *counters=summary[@"counters"];
    CHECK([counters[@"log.upload_end.success"] intValue]==1);
    CHECK([counters[@"log.upload_end.request_body_bytes"] intValue]==5);
    CHECK([counters[@"log.upload_end.response_body_bytes"] intValue]==2);
    CHECK(![summary[@"incomplete"] boolValue]);
    CHECK([summary[@"in_flight_uploads"] intValue]==0);
    CHECK([summary[@"last_error"] isEqual:NSNull.null]);
    CHECK([diagnostics exportSession:session toDirectory:export error:&error]);
    NSDictionary *saved=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[export URLByAppendingPathComponent:@"summary.json"]] options:0 error:&error];
    CHECK([saved[@"counters"] isEqual:counters]);
    NSString *lines=[NSString stringWithContentsOfURL:[export URLByAppendingPathComponent:@"events.jsonl"] encoding:NSUTF8StringEncoding error:&error];
    NSArray *rows=[lines componentsSeparatedByString:@"\n"];CHECK(rows.count==3);
    for(NSUInteger i=0;i<records.count;i++){
        NSDictionary *row=[NSJSONSerialization JSONObjectWithData:[rows[i] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        CHECK([row isEqual:records[i]]);
    }
    [diagnostics close];
    diagnostics=[[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];CHECK(diagnostics);
    CHECK([[diagnostics summary:session error:&error][@"counters"] isEqual:counters]);
    CHECK([[diagnostics records:session offset:0 limit:100 error:&error] isEqual:records]);
    [diagnostics close];
    printf("Actual FTHTTPClient -> FTDiagnostics -> export/reopen passed: HTTP 200, request=5 bytes, response=2 bytes, records=2, success=1, in_flight=0\n");
    // Opt in to retaining the verified raw export for inspection; destination must be new.
    NSString *samplePath=NSProcessInfo.processInfo.environment[@"FT_DIAGNOSTICS_SAMPLE_DIR"];
    if(samplePath.length){
        NSURL *sample=[NSURL fileURLWithPath:samplePath isDirectory:YES];
        CHECK([NSFileManager.defaultManager copyItemAtURL:export toURL:sample error:&error]);
        printf("Verified raw diagnostics export: %s\n",sample.path.UTF8String);
    }
    for(NSURL *url in @[root,export])CHECK([NSFileManager.defaultManager removeItemAtURL:url error:&error]);
}return 0;}
