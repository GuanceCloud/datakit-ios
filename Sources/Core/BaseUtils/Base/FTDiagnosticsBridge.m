//  Copyright 2026 Shanghai Guance Information Technology Co., Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FTDiagnosticsBridge.h"
#import <stdatomic.h>
static FTDiagnosticsSink FTSink;
static atomic_bool FTDiagnosticsEnabled = false;
static NSDictionary *FTDiagnosticEvent(NSString *kind, NSString *channel) {
    return @{@"event_type":kind, @"channel":[FTDiagnosticsBridge channel:channel],
             @"time_ms":@((int64_t)(NSDate.date.timeIntervalSince1970*1000))};
}
static void FTDeliver(FTDiagnosticsSink sink, NSDictionary *event) {
    if (sink) @try { sink([event copy]); } @catch (__unused NSException *e) { }
}
@interface FTDiagnosticsAttempt ()
@property (copy) FTDiagnosticsSink sink;
@property NSString *channel;
@property NSString *identifier;
@property NSTimeInterval started;
@property BOOL finished;
@end
@implementation FTDiagnosticsBridge
+ (BOOL)enabled { return atomic_load(&FTDiagnosticsEnabled); }
+ (BOOL)install:(FTDiagnosticsSink)sink {
    @synchronized(self) { if (FTSink) return NO; FTSink=[sink copy]; atomic_store(&FTDiagnosticsEnabled,true); return YES; }
}
+ (void)uninstall:(FTDiagnosticsSink)sink {
    @synchronized(self) { if (FTSink==sink) { atomic_store(&FTDiagnosticsEnabled,false); FTSink=nil; } }
}
+ (FTDiagnosticsSink)currentSink { @synchronized(self) { return FTSink; } }
+ (NSString *)channel:(NSString *)value {
    NSString *v=value.lowercaseString ?: @"";
    if ([v containsString:@"replay"] || [v containsString:@"resource"] || [v containsString:@"segment"]) return @"replay";
    if ([v containsString:@"log"]) return @"log";
    if ([v containsString:@"rum"]) return @"rum";
    return @"other";
}
+ (void)record:(NSString *)kind channel:(NSString *)channel count:(int64_t)count bytes:(int64_t)bytes reason:(NSString *)reason {
    if (![self enabled]) return;
    FTDiagnosticsSink sink=[self currentSink];
    NSMutableDictionary *e=[FTDiagnosticEvent(kind,channel) mutableCopy];
    if(count>=0)e[@"count"]=@(count); if(bytes>=0)e[@"bytes"]=@(bytes);
    e[@"reason"]=reason; FTDeliver(sink,e);
}
+ (void)batch:(NSString *)channel count:(int64_t)count bytes:(int64_t)bytes ageMs:(int64_t)age source:(NSString *)source {
    if(![self enabled])return;FTDiagnosticsSink sink=[self currentSink];
    NSMutableDictionary *e=[FTDiagnosticEvent(@"batch",channel) mutableCopy];
    if(count>=0)e[@"count"]=@(count);if(bytes>=0)e[@"bytes"]=@(bytes);
    if(age>=0)e[@"age_ms"]=@(age);e[@"age_source"]=source;FTDeliver(sink,e);
}
+ (FTDiagnosticsAttempt *)begin:(NSString *)channel payloadBytes:(int64_t)bytes {
    if (![self enabled]) return nil;
    FTDiagnosticsSink sink=[self currentSink]; if(!sink)return nil;
    FTDiagnosticsAttempt *a=[FTDiagnosticsAttempt new]; a.sink=sink; a.channel=channel;
    a.identifier=NSUUID.UUID.UUIDString; a.started=NSProcessInfo.processInfo.systemUptime;
    NSMutableDictionary *e=[FTDiagnosticEvent(@"upload_start",channel) mutableCopy];
    e[@"attempt_id"]=a.identifier; if(bytes>=0)e[@"payload_bytes"]=@(bytes); FTDeliver(sink,e);
    return a;
}
@end
@implementation FTDiagnosticsAttempt
- (void)finishWithStatus:(NSInteger)status requestBytes:(int64_t)tx responseBytes:(int64_t)rx source:(NSString *)source {
    [self finishWithStatus:status transportError:NO requestBytes:tx responseBytes:rx source:source];
}
- (void)finishWithStatus:(NSInteger)status transportError:(BOOL)failed requestBytes:(int64_t)tx responseBytes:(int64_t)rx source:(NSString *)source {
    @synchronized(self) {
        if(self.finished)return; self.finished=YES;
        NSMutableDictionary *e=[FTDiagnosticEvent(@"upload_end",self.channel) mutableCopy];
        e[@"attempt_id"]=self.identifier;
        e[@"duration_ms"]=@((NSProcessInfo.processInfo.systemUptime-self.started)*1000);
        e[@"status_code"]=@(status); e[@"outcome"]=(!failed && status>=200 && status<300)?@"success":@"failure";
        e[@"transport_error"]=@(failed);
        if(tx>=0)e[@"request_body_bytes"]=@(tx); if(rx>=0)e[@"response_body_bytes"]=@(rx);
        e[@"byte_source"]=source; e[@"byte_availability"]=(tx>=0 && rx>=0)?@"observed":@"unavailable_or_partial";
        FTDeliver(self.sink,e); self.sink=nil;
    }
}
@end
