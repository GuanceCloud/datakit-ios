#import <Foundation/Foundation.h>
#import "FTDiagnostics.h"
#import "FTDiagnosticsBridge.h"
#define CHECK(x) do { if(!(x)){fprintf(stderr,"Failed line %d: %s\n",__LINE__,#x);abort();} }while(0)
static NSURL *temp(void){NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];return url;}
int main(void){@autoreleasepool {
    NSError *error=nil;NSURL *root=temp();
    FTDiagnostics *d=[[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];CHECK(d);
    NSString *first=[d start:&error];CHECK(first);
    [FTDiagnosticsBridge record:@"storage_write" channel:@"log" count:3 bytes:60 reason:@"sqlite_insert"];
    FTDiagnosticsAttempt *old=[FTDiagnosticsBridge begin:@"log" payloadBytes:30];
    NSDictionary *ended=[d stop:&error];CHECK([ended[@"in_flight_uploads"] intValue]==1);CHECK([ended[@"incomplete"] boolValue]);
    CHECK([ended[@"counters"][@"log.storage_write.count"] intValue]==3);
    NSString *second=[d start:&error];CHECK(second);
    [old finishWithStatus:200 requestBytes:30 responseBytes:0 source:@"test"];
    FTDiagnosticsAttempt *current=[FTDiagnosticsBridge begin:@"rum" payloadBytes:42];
    [current finishWithStatus:200 requestBytes:20 responseBytes:5 source:@"test"];
    [current finishWithStatus:200 requestBytes:20 responseBytes:5 source:@"test"];
    NSDictionary *summary=[d stop:&error];CHECK([summary[@"in_flight_uploads"] intValue]==0);
    CHECK(!summary[@"counters"][@"log.upload_end.observations"]);CHECK([summary[@"counters"][@"rum.upload_end.success"] intValue]==1);
    CHECK([d records:first offset:0 limit:100 error:&error].count==1);
    CHECK([d records:second offset:1 limit:1 error:&error].count==1);
    NSURL *export=temp();CHECK([d exportSession:second toDirectory:export error:&error]);
    CHECK([d deleteSession:first error:&error]);CHECK([d sessions:&error].count==1);
    CHECK(![[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error]);
    [d close];CHECK(![FTDiagnosticsBridge enabled]);
    // Recover an interrupted writer from its last atomic checkpoint.
    NSURL *summaryURL=[[root URLByAppendingPathComponent:second] URLByAppendingPathComponent:@"summary.json"];
    NSMutableDictionary *saved=[[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:summaryURL] options:0 error:nil] mutableCopy];
    saved[@"state"]=@"active";[[NSJSONSerialization dataWithJSONObject:saved options:0 error:nil] writeToURL:summaryURL atomically:YES];
    d=[[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];CHECK(d);
    CHECK([[d summary:second error:&error][@"state"] isEqual:@"interrupted"]);[d close];
    // Broken checkpoints remain discoverable; retention follows the saved timestamp.
    [@"broken" writeToURL:summaryURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    d=[[FTDiagnostics alloc]initWithDirectory:root config:[FTDiagnosticsConfig new] error:&error];CHECK(d);
    saved=[[d summary:second error:&error] mutableCopy];CHECK([saved[@"state"] isEqual:@"interrupted"]);
    saved[@"updated_ms"]=@((int64_t)((NSDate.date.timeIntervalSince1970-8*24*3600)*1000));
    [[NSJSONSerialization dataWithJSONObject:saved options:0 error:nil] writeToURL:summaryURL atomically:YES];
    CHECK([d cleanExpired:&error]);CHECK([d sessions:&error].count==0);
    // A completion racing with stop cannot contaminate the next session.
    CHECK([d start:&error]);NSMutableArray *attempts=[NSMutableArray new];
    for(int i=0;i<100;i++)[attempts addObject:[FTDiagnosticsBridge begin:@"log" payloadBytes:1]];
    dispatch_group_t group=dispatch_group_create();
    dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{
        for(FTDiagnosticsAttempt *a in attempts)[a finishWithStatus:200 requestBytes:1 responseBytes:0 source:@"test"];
    });
    ended=[d stop:&error];CHECK([ended[@"counters"][@"log.upload_end.observations"] intValue]+[ended[@"in_flight_uploads"] intValue]==100);
    CHECK([d start:&error]);dispatch_group_wait(group,DISPATCH_TIME_FOREVER);
    summary=[d stop:&error];CHECK([summary[@"counters"] count]==0);
    // HTTP 200 headers followed by a transport error are not a successful upload.
    CHECK([d start:&error]);FTDiagnosticsAttempt *partial=[FTDiagnosticsBridge begin:@"log" payloadBytes:1];
    [partial finishWithStatus:200 transportError:YES requestBytes:1 responseBytes:1 source:@"test"];
    summary=[d stop:&error];CHECK([summary[@"counters"][@"log.upload_end.failure"] intValue]==1);[d close];
    // Detail quota must not disable bounded aggregate collection.
    FTDiagnosticsConfig *config=[FTDiagnosticsConfig new];config.sessionBytes=128*1024;config.totalBytes=128*1024;
    NSURL *limitedRoot=temp();d=[[FTDiagnostics alloc]initWithDirectory:limitedRoot config:config error:&error];CHECK(d);
    NSString *limited=[d start:&error];CHECK(limited);
    for(int i=0;i<8000;i++)[FTDiagnosticsBridge record:@"retry" channel:@"replay" count:1 bytes:-1 reason:@"retry_scheduled"];
    summary=[d stop:&error];CHECK([summary[@"counters"][@"replay.retry.count"] intValue]==8000);CHECK([summary[@"omitted_records"] intValue]>0);
    NSString *next=[d start:&error];CHECK(next);CHECK([d sessions:&error].count==1);
    CHECK(![d deleteSession:next error:&error]);[d stop:&error];[d close];
    // Local IO failure is exposed without throwing into SDK operations.
    NSURL *failedRoot=temp();d=[[FTDiagnostics alloc]initWithDirectory:failedRoot config:config error:&error];CHECK(d);
    NSString *failed=[d start:&error];NSURL *events=[[failedRoot URLByAppendingPathComponent:failed] URLByAppendingPathComponent:@"events.jsonl"];
    CHECK([NSFileManager.defaultManager removeItemAtURL:events error:&error]);CHECK([NSFileManager.defaultManager createDirectoryAtURL:events withIntermediateDirectories:NO attributes:nil error:&error]);
    [FTDiagnosticsBridge record:@"retry" channel:@"log" count:1 bytes:-1 reason:@"retry_scheduled"];
    summary=[d stop:&error];CHECK([summary[@"last_error"] isEqual:@"local_write_failed"]);[d close];
    for(NSURL *url in @[root,export,limitedRoot,failedRoot])[NSFileManager.defaultManager removeItemAtURL:url error:nil];
    puts("Diagnostics lifecycle, isolation, recovery, quotas and IO failure checks passed");
}return 0;}
