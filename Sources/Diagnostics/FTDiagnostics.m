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

#import "FTDiagnostics.h"
#import "FTDiagnosticsBridge.h"
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
static const uint64_t FTReserve=64*1024;
static BOOL FTFailure(NSError **error, NSString *message) {
    if(error)*error=[NSError errorWithDomain:@"com.ft.diagnostics" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
static BOOL FTWriteJSON(NSURL *url, NSDictionary *value, NSError **error) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:error];
    if(!data)return NO;
    if(data.length>FTReserve/2)return FTFailure(error,@"Summary limit exceeded");
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}
static NSDictionary *FTReadJSON(NSURL *url,NSError **error) {
    NSNumber *size; [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if(size.unsignedLongLongValue>FTReserve){FTFailure(error,@"Invalid summary size");return nil;}
    NSData *data=[NSData dataWithContentsOfURL:url options:0 error:error]; if(!data)return nil;
    id obj=[NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if(![obj isKindOfClass:NSDictionary.class]){FTFailure(error,@"Invalid summary");return nil;} return obj;
}
static uint64_t FTSize(NSURL *url) {
    uint64_t size=0;
    for(NSURL *f in [NSFileManager.defaultManager enumeratorAtURL:url includingPropertiesForKeys:@[NSURLFileSizeKey] options:0 errorHandler:nil]) {
        NSNumber *n;[f getResourceValue:&n forKey:NSURLFileSizeKey error:nil];size+=n.unsignedLongLongValue;
    } return size;
}
@implementation FTDiagnosticsConfig
- (instancetype)init { if((self=[super init])){_sessionBytes=20*1024*1024;_totalBytes=100*1024*1024;_retentionSeconds=7*24*3600;}return self; }
- (id)copyWithZone:(NSZone *)zone { FTDiagnosticsConfig *c=[FTDiagnosticsConfig new];c.sessionBytes=self.sessionBytes;c.totalBytes=self.totalBytes;c.retentionSeconds=self.retentionSeconds;return c; }
@end
@interface FTDiagnosticSession : NSObject
@property NSURL *directory;
@property NSString *identifier;
@property NSString *state;
@property NSString *lastError;
@property NSMutableDictionary *counters;
@property dispatch_queue_t queue;
@property dispatch_source_t timer;
@property FTDiagnosticsSink sink;
@property BOOL accepting, incomplete;
@property uint64_t omitted, recordCount, detailBytes, inFlight, pending, limit;
@property int64_t started;
- (NSDictionary *)snapshot;
- (void)record:(NSDictionary *)event;
@end
@implementation FTDiagnosticSession
- (instancetype)init {
    if((self=[super init])){
        _counters=[NSMutableDictionary new];_state=@"active";_accepting=YES;
        _started=(int64_t)(NSDate.date.timeIntervalSince1970*1000);
        _queue=dispatch_queue_create("com.ft.diagnostics.writer",DISPATCH_QUEUE_SERIAL);
    }return self;
}
- (NSDictionary *)snapshot { @synchronized(self) {
    return @{@"schema_version":@1,@"session_id":self.identifier,@"platform":@"ios",@"state":self.state,
             @"started_ms":@(self.started),@"updated_ms":@((int64_t)(NSDate.date.timeIntervalSince1970*1000)),
             @"process_scope":@"caller_process",@"process_id":@(getpid()),@"process_name":NSProcessInfo.processInfo.processName,
             @"backlog_semantics":@"last_successful_storage_observation; log/rum=events,replay=files; not cross-process additive",@"counters":[self.counters copy],@"omitted_records":@(self.omitted),
             @"records":@(self.recordCount),@"pending_records":@(self.pending),@"in_flight_uploads":@(self.inFlight),
             @"incomplete":@(self.incomplete || (![self.state isEqual:@"active"] && self.inFlight>0)),
             @"last_error":self.lastError ?: NSNull.null,
             @"http_scope":@"observed_body_bytes_excludes_headers_tls_tcp; consult per-attempt byte_source"};
} }
- (void)add:(NSString *)key value:(double)value { self.counters[key]=@([self.counters[key] doubleValue]+value); }
- (void)persist {
    if(!FTWriteJSON([self.directory URLByAppendingPathComponent:@"summary.json"],[self snapshot],nil)) {
        @synchronized(self){self.lastError=@"summary_write_failed";self.incomplete=YES;}
    }
}
- (void)record:(NSDictionary *)event { @synchronized(self) {
    if(!self.accepting)return;
    NSString *kind=event[@"event_type"],*channel=event[@"channel"];
    if(![@[@"log",@"rum",@"replay",@"other"] containsObject:channel])return;
    if(![@[@"storage_write",@"storage_remove",@"discard",@"backlog",@"batch",@"retry",@"upload_start",@"upload_end"] containsObject:kind])return;
    NSString *prefix=[NSString stringWithFormat:@"%@.%@",channel,kind];
    [self add:[prefix stringByAppendingString:@".observations"] value:1];
    NSString *reason=event[@"reason"];
    if(reason){
        NSArray *allowed=@[@"cache_policy",@"sqlite_insert",@"sqlite_write_failed",@"sqlite_rollback",@"upload_cleanup",@"capacity_cleanup",@"explicit_cleanup",@"expired_or_cache_cleanup",@"retry_scheduled",@"non_retryable_response",@"file_append",@"file_write",@"file_delete",@"expired_file",@"item_size_limit"];
        [self add:[NSString stringWithFormat:@"%@.reason.%@",prefix,[allowed containsObject:reason]?reason:@"other"] value:1];
    }
    for(NSString *key in @[@"count",@"bytes",@"payload_bytes",@"request_body_bytes",@"response_body_bytes",@"duration_ms",@"age_ms"]) {
        id value=event[key];
        if([value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) && [value doubleValue]>=0) {
            NSString *name=[NSString stringWithFormat:@"%@.%@",prefix,key];
            if([kind isEqual:@"backlog"]){self.counters[name]=value;self.counters[[prefix stringByAppendingString:@".observed_ms"]]=event[@"time_ms"];} else {
                [self add:name value:[value doubleValue]];[self add:[name stringByAppendingString:@".samples"] value:1];
                NSString *maxKey=[name stringByAppendingString:@".max"];
                self.counters[maxKey]=@(MAX([self.counters[maxKey] doubleValue],[value doubleValue]));
            }
        }
    }
    if([kind isEqual:@"upload_start"])self.inFlight++;
    if([kind isEqual:@"upload_end"]){if(self.inFlight)self.inFlight--;[self add:[NSString stringWithFormat:@"%@.%@",prefix,[event[@"outcome"] isEqual:@"success"]?@"success":@"failure"] value:1];}
    if([kind isEqual:@"storage_write"])return;
    if(self.pending>=1024){self.omitted++;self.incomplete=YES;return;}
    self.pending++;
    NSMutableDictionary *row=[event mutableCopy];row[@"schema_version"]=@1;row[@"session_id"]=self.identifier;
    dispatch_async(self.queue,^{ @autoreleasepool {
        NSData *json=[NSJSONSerialization dataWithJSONObject:row options:0 error:nil];
        NSMutableData *line=[json mutableCopy];[line appendBytes:"\n" length:1];
        BOOL allowed;
        @synchronized(self){allowed=json && self.detailBytes+line.length<=self.limit-FTReserve;}
        if(allowed){
            NSError *error;
            NSFileHandle *file=[NSFileHandle fileHandleForWritingToURL:[self.directory URLByAppendingPathComponent:@"events.jsonl"] error:&error];
            BOOL ok=file && [file seekToEndReturningOffset:nil error:&error] && [file writeData:line error:&error];
            [file closeAndReturnError:nil];
            @synchronized(self){if(ok){self.detailBytes+=line.length;self.recordCount++;}else{self.omitted++;self.incomplete=YES;self.lastError=@"local_write_failed";}}
        }else{@synchronized(self){self.omitted++;self.incomplete=YES;}}
        @synchronized(self){self.pending--;}
    }});
} }
@end
@interface FTDiagnostics ()
@property NSURL *root;
@property FTDiagnosticsConfig *config;
@property FTDiagnosticSession *active;
@property int lockFD;
@property BOOL closed;
@end
@implementation FTDiagnostics
- (instancetype)initWithDirectory:(NSURL *)directory config:(FTDiagnosticsConfig *)config error:(NSError **)error {
    if(!(self=[super init]))return nil;
    _lockFD=-1;
    if(!directory.isFileURL || config.sessionBytes<128*1024 || config.totalBytes<config.sessionBytes || config.retentionSeconds<=0){FTFailure(error,@"Invalid diagnostics configuration");return nil;}
    _root=directory.URLByStandardizingPath.URLByResolvingSymlinksInPath;_config=[config copy];
    if(![NSFileManager.defaultManager createDirectoryAtURL:_root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return nil;
    _lockFD=open([[_root URLByAppendingPathComponent:@".lock"] fileSystemRepresentation],O_CREAT|O_RDWR,0600);
    if(_lockFD<0 || flock(_lockFD,LOCK_EX|LOCK_NB)!=0){FTFailure(error,@"Diagnostics directory in use");if(_lockFD>=0)close(_lockFD);_lockFD=-1;return nil;}
    for(NSURL *dir in [self directories]) {
        NSMutableDictionary *summary=[FTReadJSON([dir URLByAppendingPathComponent:@"summary.json"],nil) mutableCopy];
        if(!summary)summary=[@{@"schema_version":@1,@"session_id":dir.lastPathComponent,@"state":@"active",@"last_error":@"checkpoint_unavailable"} mutableCopy];
        if([summary[@"state"] isEqual:@"active"]){summary[@"state"]=@"interrupted";summary[@"incomplete"]=@YES;if(!FTWriteJSON([dir URLByAppendingPathComponent:@"summary.json"],summary,error))return nil;}
    }
    if(![self prune:0 error:error])return nil;
    return self;
}
- (NSArray<NSURL *> *)directories {
    NSArray *items=[NSFileManager.defaultManager contentsOfDirectoryAtURL:self.root includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray *dirs=[NSMutableArray new];
    for(NSURL *url in items) {
        NSNumber *link,*directory;
        [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
        if([[NSUUID alloc]initWithUUIDString:url.lastPathComponent] && directory.boolValue && !link.boolValue)[dirs addObject:url];
    }
    return [dirs sortedArrayUsingComparator:^NSComparisonResult(NSURL *a,NSURL *b){NSDate *x,*y;[a getResourceValue:&x forKey:NSURLContentModificationDateKey error:nil];[b getResourceValue:&y forKey:NSURLContentModificationDateKey error:nil];return [x compare:y];}];
}
- (BOOL)prune:(uint64_t)reserve error:(NSError **)error {
    NSArray *dirs=[self directories];uint64_t total=0;for(NSURL *dir in dirs)total+=FTSize(dir);
    for(NSURL *dir in dirs){
        if([dir.path isEqual:self.active.directory.path])continue;
        NSDate *date;[dir getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
        NSDictionary *summary=FTReadJSON([dir URLByAppendingPathComponent:@"summary.json"],nil);
        NSTimeInterval retained=summary[@"updated_ms"] ? [summary[@"updated_ms"] doubleValue]/1000 : date.timeIntervalSince1970;
        if(NSDate.date.timeIntervalSince1970-retained>self.config.retentionSeconds || total+reserve>self.config.totalBytes){
            uint64_t size=FTSize(dir);if(![NSFileManager.defaultManager removeItemAtURL:dir error:error])return NO;total-=size;
        }
    }
    return total+reserve<=self.config.totalBytes || FTFailure(error,@"Diagnostic storage limit reached");
}
- (NSString *)start:(NSError **)error { @synchronized(self) {
    if(self.closed || self.active){FTFailure(error,@"Collector closed or session active");return nil;}
    if(![self prune:self.config.sessionBytes error:error])return nil;
    FTDiagnosticSession *s=[FTDiagnosticSession new];s.identifier=NSUUID.UUID.UUIDString;s.limit=self.config.sessionBytes;
    s.directory=[self.root URLByAppendingPathComponent:s.identifier];
    if(![NSFileManager.defaultManager createDirectoryAtURL:s.directory withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error])return nil;
    if(![NSData.data writeToURL:[s.directory URLByAppendingPathComponent:@"events.jsonl"] options:0 error:error] || !FTWriteJSON([s.directory URLByAppendingPathComponent:@"summary.json"],[s snapshot],error))return nil;
    __weak FTDiagnosticSession *weak=s;
    s.sink=^(NSDictionary *event){[weak record:event];};
    if(![FTDiagnosticsBridge install:s.sink]){[NSFileManager.defaultManager removeItemAtURL:s.directory error:nil];FTFailure(error,@"Another collector is active");return nil;}
    self.active=s;
    s.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,s.queue);
    dispatch_source_set_timer(s.timer,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),NSEC_PER_SEC,NSEC_PER_MSEC*100);
    dispatch_source_set_event_handler(s.timer,^{[weak persist];});dispatch_resume(s.timer);
    return s.identifier;
} }
- (NSDictionary *)stop:(NSError **)error { @synchronized(self) {
    FTDiagnosticSession *s=self.active;if(!s){FTFailure(error,@"No active session");return nil;}
    [FTDiagnosticsBridge uninstall:s.sink];
    @synchronized(s){s.accepting=NO;s.state=@"stopped";}
    dispatch_source_cancel(s.timer);dispatch_sync(s.queue,^{[s persist];});
    self.active=nil;return [s snapshot];
} }
- (NSDictionary *)status { @synchronized(self){return self.active?[self.active snapshot]:@{@"state":self.closed?@"closed":@"idle"};} }
- (NSURL *)sessionURL:(NSString *)identifier error:(NSError **)error {
    if(self.closed || ![[NSUUID alloc]initWithUUIDString:identifier]){FTFailure(error,@"Invalid session ID or closed collector");return nil;}
    NSURL *url=[self.root URLByAppendingPathComponent:identifier];
    NSNumber *link;[url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
    if(link.boolValue || ![NSFileManager.defaultManager fileExistsAtPath:url.path]){FTFailure(error,@"Unknown session");return nil;}return url;
}
- (NSArray *)sessions:(NSError **)error { @synchronized(self){NSMutableArray *result=[NSMutableArray new];for(NSURL *url in [self directories]){NSDictionary *s=[self summary:url.lastPathComponent error:error];if(!s)return nil;[result addObject:s];}return result;} }
- (NSDictionary *)summary:(NSString *)identifier error:(NSError **)error { @synchronized(self){if([self.active.identifier isEqual:identifier])return [self.active snapshot];NSURL *url=[self sessionURL:identifier error:error];return url?FTReadJSON([url URLByAppendingPathComponent:@"summary.json"],error):nil;} }
- (NSArray *)records:(NSString *)identifier offset:(NSUInteger)offset limit:(NSUInteger)limit error:(NSError **)error { @synchronized(self){
    if(limit<1 || limit>1000){FTFailure(error,@"Invalid page size");return nil;}
    NSURL *url=[self sessionURL:identifier error:error];if(!url)return nil;
    FILE *file=fopen([[url URLByAppendingPathComponent:@"events.jsonl"] fileSystemRepresentation],"r");
    if(!file){FTFailure(error,@"Cannot read records");return nil;}
    NSMutableArray *result=[NSMutableArray new];char *line=NULL;size_t capacity=0;ssize_t n;NSUInteger index=0;
    while(result.count<limit && (n=getline(&line,&capacity,file))>0){
        if(index++<offset)continue;
        if(line[n-1]!='\n')break;
        id row=[NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:line length:(NSUInteger)n] options:0 error:nil];
        if(![row isKindOfClass:NSDictionary.class])break;[result addObject:row];
    }free(line);fclose(file);return result;
} }
- (BOOL)exportSession:(NSString *)identifier toDirectory:(NSURL *)destination error:(NSError **)error { @synchronized(self){
    if([self.active.identifier isEqual:identifier])return FTFailure(error,@"Stop session first");
    NSURL *source=[self sessionURL:identifier error:error];if(!source)return NO;
    NSURL *dest=destination.URLByStandardizingPath.URLByResolvingSymlinksInPath;
    if(!dest.isFileURL || [dest.path isEqual:self.root.path] || [dest.path hasPrefix:[self.root.path stringByAppendingString:@"/"]] || [self.root.path hasPrefix:[dest.path stringByAppendingString:@"/"]])return FTFailure(error,@"Export must be outside diagnostic storage");
    if([NSFileManager.defaultManager fileExistsAtPath:dest.path])return FTFailure(error,@"Export destination must be new");
    if(![NSFileManager.defaultManager createDirectoryAtURL:dest withIntermediateDirectories:YES attributes:nil error:error])return NO;
    for(NSString *name in @[@"summary.json",@"events.jsonl"])if(![NSFileManager.defaultManager copyItemAtURL:[source URLByAppendingPathComponent:name] toURL:[dest URLByAppendingPathComponent:name] error:error])return NO;
    return YES;
} }
- (BOOL)deleteSession:(NSString *)identifier error:(NSError **)error { @synchronized(self){
    if([self.active.identifier isEqual:identifier])return FTFailure(error,@"Stop session first");
    NSURL *url=[self sessionURL:identifier error:error];return url && [NSFileManager.defaultManager removeItemAtURL:url error:error];
} }
- (BOOL)cleanExpired:(NSError **)error { @synchronized(self){return [self prune:0 error:error];} }
- (void)close { @synchronized(self){if(self.closed)return;if(self.active)[self stop:nil];if(self.lockFD>=0){flock(self.lockFD,LOCK_UN);close(self.lockFD);self.lockFD=-1;}self.closed=YES;} }
- (void)dealloc { [self close]; }
@end
