//
//  FTCrashReportWrapper.m
//
//  Created by hulilei on 2025/12/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FTCrashReportWrapper.h"
#import "FTCrashReportFields.h"
#import "FTCrashReport.h"
#import <pthread.h>
#import "FTCrashBacktrace.h"
#import "FTSDKCompat.h"
#import "FTPresetProperty.h"
#import <sys/utsname.h>
#import "FTCrashThread.h"
#import "FTErrorDataProtocol.h"
#import "FTCrashMachineContext.h"
#import "FTCrashStackCursor.h"
#import "FTCrashStackCursor_MachineContext.h"
#import "FTCrashDynamicLinker.h"

#if FT_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

#if defined(__LP64__)
#define FMT_LONG_DIGITS "16"
#define FMT_RJ_SPACES "18"
#else
#define FMT_LONG_DIGITS "8"
#define FMT_RJ_SPACES "10"
#endif

#define FMT_PTR_SHORT @"0x%" PRIxPTR
#define FMT_PTR_LONG @"0x%0" FMT_LONG_DIGITS PRIxPTR
// #define FMT_PTR_RJ           @"%#" FMT_RJ_SPACES PRIxPTR
#define FMT_PTR_RJ @"%#" PRIxPTR
#define FMT_OFFSET @"%" PRIuPTR
#define FMT_TRACE_PREAMBLE @"%-4d%-30s\t" FMT_PTR_SHORT
#define FMT_TRACE_UNSYMBOLICATED FMT_PTR_SHORT @" + " FMT_OFFSET
#define FMT_TRACE_SYMBOLICATED @"%@ + " FMT_OFFSET

#define kAppleRedactedText @"<redacted>"

#define MAX_STACKTRACE_LENGTH 100

typedef struct {
    FTCrashThread thread;
    FTCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH];
    int stackLength;
} FTThreadInfo;
unsigned int
getStackEntriesFromThread(FTCrashThread thread, struct FTCrashMachineContext *context,
                          FTCrashStackEntry *buffer, unsigned int maxEntries, bool symbolicate)
{
    ftcrashmc_getContextForThread(thread, context, NO);
    FTCrashStackCursor stackCursor;

    ftcrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);

    unsigned int entries = 0;
    while (stackCursor.advanceCursor(&stackCursor)) {
        if (entries == maxEntries)
            break;
        if (symbolicate == false || stackCursor.symbolicate(&stackCursor)) {
            buffer[entries] = stackCursor.stackEntry;
            entries++;
        }
    }

    return entries;
}

@implementation FTCrashReportWrapper
static mach_port_t main_thread_id;
/** Date formatter for Apple date format in crash reports. */
static NSDateFormatter *g_dateFormatter;

+ (void)load{
    main_thread_id = mach_thread_self();
}
- (void)filterReports:(NSArray<id<FTCrashReport>> *)reports
         onCompletion:(nullable FTCrashReportFilterCompletion)onCompletion{
    NSMutableArray<id<FTCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (FTCrashReportDictionary *report in reports) {
        if ([report isKindOfClass:[FTCrashReportDictionary class]] == NO) {
            //            FTLOG_ERROR(@"Unexpected non-dictionary report: %@", report);
            continue;
        }
        NSDictionary *userInfo = report.value[FTCrashField_RecrashReport];
        if (userInfo != nil) {
            [filteredReports addObject:[FTCrashReportDictionary reportWithValue:userInfo]];
        }
    }

    ftcrash_callCompletion(onCompletion, filteredReports, nil);
}
- (NSString *)generateMainThreadBacktrace{
    return [self generateBacktrace:main_thread_id];
}
-(NSString *)generateBacktrace:(thread_t)thread{
    FTCrashMachineContext context = { 0 };
    FTCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH] = {0};
    NSMutableString *threadStr = [NSMutableString string];
    NSMutableDictionary *imagesDict = [NSMutableDictionary new];
    int count = getStackEntriesFromThread(thread,&context,stackEntries,MAX_STACKTRACE_LENGTH,true);
    if (count>0)  {
        NSString *name = [self getThreadName:thread];
        if (name) {
            [threadStr appendFormat:@"\nThread %d name:  %@\n", 0, name];
        }else{
            [threadStr appendFormat:@"\nThread %d:\n",0];
        }
        for (int index = 0; index< count; index++) {
            FTCrashStackEntry entry = stackEntries[index];
            if (entry.imageName) {
                NSString *path = [NSString stringWithUTF8String:entry.imageName];
                NSString *name = [path lastPathComponent];
                [threadStr appendFormat:FMT_TRACE_PREAMBLE @" " FMT_TRACE_UNSYMBOLICATED, index, [name UTF8String], entry.address, entry.imageAddress, entry.address - entry.imageAddress];
                if (imagesDict[@(entry.imageAddress)] == nil) {
                    FTCrashBinaryImage image = { 0 };
                    ftcrashdl_binaryImageForHeader((void *)entry.imageAddress,entry.imageName,&image);
                    cpu_type_t cpuType = image.cpuType;
                    cpu_subtype_t cpuSubtype = image.cpuSubType;
                    uintptr_t imageAddr = image.address;
                    uintptr_t imageSize = image.size;
                    NSString *uuid = [self toCompactUUID:[[[NSUUID alloc]initWithUUIDBytes:image.uuid] UUIDString]];
                    NSString *arch = [FTPresetProperty CPUArchForMajor:cpuType minor:cpuSubtype];
                    NSString *imageStr = [NSString stringWithFormat:FMT_PTR_RJ @" - " FMT_PTR_RJ @" %@ %@  <%@> %@", imageAddr, imageAddr + imageSize - 1,
                                          name, arch, uuid, path];
                    imagesDict[@(imageAddr)] = imageStr;
                }
            }else{
                [threadStr appendFormat:@"%-4d ??? 0x%016llx 0x0 + 0",index, (unsigned long long)entry.address];
            }
            [threadStr appendString:@"\n"];
        }
        [threadStr appendString:@"\nBinary Images:\n"];
        [threadStr appendString:[imagesDict.allValues componentsJoinedByString:@"\n"]];
        [threadStr appendString:@"\nEOF\n\n"];
        NSString *header = [self headStringForFreeze];
        [threadStr insertString:header atIndex:0];
        return threadStr;
    }
    return nil;
}
-(NSString *)generateAllThreadsBacktrace{
    @synchronized(self) {
        FTCrashThread currentThread = ftcrashthread_self();
        FTCrashMachineContext context = { 0 };
        thread_act_array_t suspendedThreads = NULL;
        mach_msg_type_number_t numSuspendedThreads = 0;
        ftcrashmc_suspendEnvironment_upToMaxSupportedThreads(&suspendedThreads,&numSuspendedThreads,70);
        if (numSuspendedThreads == 0) {
            return nil;
        }
        int numThreads = numSuspendedThreads;
        FTThreadInfo threadsInfos[numSuspendedThreads];
        for (int i = 0; i < numSuspendedThreads; i++) {
            if (suspendedThreads[i] != currentThread) {
                int numberOfEntries = getStackEntriesFromThread(suspendedThreads[i], &context,
                    threadsInfos[i].stackEntries, MAX_STACKTRACE_LENGTH, true);
                threadsInfos[i].stackLength = numberOfEntries;
            } else {
                // We can't use 'getStackEntriesFromThread' to retrieve stack frames from the
                // current thread. We are using the stackTraceBuilder to retrieve this information
                // later.
                threadsInfos[i].stackLength = 0;
            }
            threadsInfos[i].thread = suspendedThreads[i];
        }
        ftcrashmc_resumeEnvironment(&suspendedThreads, &numSuspendedThreads);
       
        NSMutableString *threadStr = [NSMutableString string];
        NSMutableDictionary *imagesDict = [NSMutableDictionary new];
        for (int i = 0; i < numThreads; i++) {
            int count = threadsInfos[i].stackLength;
            FTCrashStackEntry *entries = threadsInfos[i].stackEntries;
            if (count>0) {
                NSString *name = [self getThreadName:threadsInfos[i].thread];
                if (name) {
                    [threadStr appendFormat:@"\nThread %d name:  %@\n", i, name];
                }else{
                    [threadStr appendFormat:@"\nThread %d:\n",i];
                }
                for (int index = 0; index< count; index++) {
                    FTCrashStackEntry entry = entries[index];
                    if (entry.imageName) {
                        NSString *path = [NSString stringWithUTF8String:entry.imageName];
                        NSString *name = [path lastPathComponent];
                        [threadStr appendFormat:FMT_TRACE_PREAMBLE @" " FMT_TRACE_UNSYMBOLICATED, index, [name UTF8String], entry.address, entry.imageAddress, entry.address - entry.imageAddress];
                        if (imagesDict[@(entry.imageAddress)] == nil) {
                            FTCrashBinaryImage image = { 0 };
                            ftcrashdl_binaryImageForHeader((void *)entry.imageAddress,entry.imageName,&image);
                            cpu_type_t cpuType = image.cpuType;
                            cpu_subtype_t cpuSubtype = image.cpuSubType;
                            uintptr_t imageAddr = image.address;
                            uintptr_t imageSize = image.size;
                            NSString *uuid = [self toCompactUUID:[[[NSUUID alloc]initWithUUIDBytes:image.uuid] UUIDString]];
                            NSString *arch = [FTPresetProperty CPUArchForMajor:cpuType minor:cpuSubtype];
                            NSString *imageStr = [NSString stringWithFormat:@"  " FMT_PTR_RJ @" - " FMT_PTR_RJ @" %@ %@  <%@> %@", imageAddr, imageAddr + imageSize - 1,
                                                  name, arch, uuid, path];
                            imagesDict[@(imageAddr)] = imageStr;
                        }
                    }else{
                        [threadStr appendFormat:@"%-4d ??? 0x%016llx 0x0 + 0",
                         index, (unsigned long long)entry.address];
                    }
                    [threadStr appendString:@"\n"];
                }
            }
        }
        [threadStr appendString:@"\nBinary Images:\n"];
        [threadStr appendString:[imagesDict.allValues componentsJoinedByString:@"\n"]];
        [threadStr appendString:@"\nEOF\n\n"];
        NSString *header = [self headStringForFreeze];
        [threadStr insertString:header atIndex:0];
        return threadStr;
    }
    return nil;
}

- (NSString *)headerStringForSystemInfo:(NSDictionary<NSString *, id> *)system
                               reportID:(nullable NSString *)reportID
                              crashTime:(nullable NSDate *)crashTime
{
    NSMutableString *str = [NSMutableString string];
    NSString *executablePath = [system objectForKey:FTCrashField_ExecutablePath];
    NSString *cpuArch = [system objectForKey:FTCrashField_CPUArch];
    NSString *cpuArchType = [self CPUType:cpuArch isSystemInfoHeader:YES];
    NSString *parentProcess = @"launchd";  // In iOS and most macOS regulard apps "launchd" is always the launcher. This
                                           // might need a fix for other kind of apps
    NSString *processRole = @"Foreground";  // In iOS and most macOS regulard apps the role is "Foreground". This might
                                            // need a fix for other kind of apps
    if (reportID) {
        [str appendFormat:@"Incident Identifier: %@\n", reportID];
    }
    [str appendFormat:@"CrashReporter Key:   %@\n", [system objectForKey:FTCrashField_DeviceAppHash]];
    [str appendFormat:@"Hardware Model:      %@\n", [system objectForKey:FTCrashField_Machine]];
    [str appendFormat:@"Process:             %@ [%@]\n", [system objectForKey:FTCrashField_ProcessName],
                      [system objectForKey:FTCrashField_ProcessID]];
    [str appendFormat:@"Path:                %@\n", executablePath];
    [str appendFormat:@"Identifier:          %@\n", [system objectForKey:FTCrashField_BundleID]];
    [str appendFormat:@"Version:             %@ (%@)\n", [system objectForKey:FTCrashField_BundleShortVersion],
                      [system objectForKey:FTCrashField_BundleVersion]];
    [str appendFormat:@"Code Type:           %@\n", cpuArchType];
    [str appendFormat:@"Role:                %@\n", processRole];
    [str appendFormat:@"Parent Process:      %@ [%@]\n", parentProcess,
                      [system objectForKey:FTCrashField_ParentProcessID]];
    [str appendFormat:@"\n"];
    if (crashTime) {
        [str appendFormat:@"Date/Time:           %@\n", [self stringFromDate:crashTime]];
    }
    [str appendFormat:@"OS Version:          %@ %@ (%@)\n", [system objectForKey:FTCrashField_SystemName],
                      [system objectForKey:FTCrashField_SystemVersion], [system objectForKey:FTCrashField_OSVersion]];
    [str appendFormat:@"Report Version:      104\n"];

    return str;
}

- (NSString *)headStringForFreeze{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSMutableString *header = [NSMutableString new];
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    [header appendFormat:@"Hardware Model:  %@\n",deviceString];
#if FT_HAS_UIDEVICE
    [header appendFormat:@"OS Version:   iPhone OS %@\n",[UIDevice currentDevice].systemVersion];
#endif
    [header appendString:@"Report Version:  104\n"];
    NSString *arch = [FTPresetProperty cpuArch];
    NSString *codeType = [self CPUType:arch isSystemInfoHeader:YES];
    [header appendFormat:@"Code Type:   %@\n",codeType];
    return header;

}
- (NSString *)toCompactUUID:(NSString *)uuid
{
    return [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}
- (NSString *)stringFromDate:(NSDate *)date
{
    if (![date isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return [g_dateFormatter stringFromDate:date];
}


- (NSString *)CPUType:(NSString *)CPUArch isSystemInfoHeader:(BOOL)isSystemInfoHeader
{
    if (isSystemInfoHeader && [CPUArch rangeOfString:@"arm64e"].location == 0) {
        return @"ARM-64 (Native)";
    }
    if ([CPUArch rangeOfString:@"arm64"].location == 0) {
        return @"ARM-64";
    }
    if ([CPUArch rangeOfString:@"arm"].location == 0) {
        return @"ARM";
    }
    if ([CPUArch isEqualToString:@"x86"]) {
        return @"X86";
    }
    if ([CPUArch isEqualToString:@"x86_64"]) {
        return @"X86_64";
    }
    return @"Unknown";
}

- (nullable NSString *)getThreadName:(FTCrashThread)thread
{
    int bufferLength = 128;
    char buffer[bufferLength];
    char *const pBuffer = buffer;

    BOOL didGetThreadNameSucceed = ftcrashthread_getThreadName(thread,pBuffer,bufferLength);

    if (didGetThreadNameSucceed == YES) {
        NSString *threadName = [NSString stringWithCString:pBuffer encoding:NSUTF8StringEncoding];
        if (threadName.length > 0) {
            return threadName;
        }
    }

    return nil;
}
@end

