//
//  FTCrashReportWrapper.m
//
//  Created by hulilei on 2025/12/12.
//  Copyright © 2025 DataFlux-cn. All rights reserved.
//
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif
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
#import "FTCrashStackCursor_SelfThread.h"
#import "FTLog+Private.h"
#import "FTFatalErrorContext.h"
#import "FTConstants.h"
#import "FTCrashJSONCodecObjC.h"
#import "FTCrashCPU.h"
#import "NSDate+FTUtil.h"
#import "FTRUMContext.h"
#include <sys/sysctl.h>

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

#define kExpectedMajorVersion 3

#define MAX_STACKTRACE_LENGTH 100

typedef struct {
    FTCrashThread thread;
    FTCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH];
    int stackLength;
} FTThreadInfo;
unsigned int
getStackEntriesFromThread(FTCrashThread thread, struct FTCrashMachineContext *context,
                          FTCrashStackEntry *buffer, unsigned int maxEntries, bool symbolicate,bool currentThread)
{
    FTCrashStackCursor stackCursor;
    if (currentThread) {
        ftcrashsc_initSelfThread(&stackCursor, 0);
    }else{
        ftcrashmc_getContextForThread(thread, context, NO);
        
        ftcrashsc_initWithMachineContext(&stackCursor, MAX_STACKTRACE_LENGTH, context);
    }
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
@interface FTCrashReportWrapper ()
@property (nonatomic, assign) BOOL enableMemory;
@property (nonatomic, assign) BOOL enableCpu;


@property (nonatomic, assign) long long crashDate;

@property (nonatomic, copy) NSString *crashMessage;

/** Convert a crash report to Apple format.
 *
 * @param JSONReport The crash report.
 *
 * @return The converted crash report.
 */
- (NSString *)toAppleFormat:(NSDictionary *)JSONReport;

/** Determine the major CPU type.
 *
 * @param CPUArch The CPU architecture name.
 *
 * @param isSystemInfoHeader Whether it is going to be used or not for system Information header
 *
 * @return the major CPU type.

 */
- (NSString *)CPUType:(NSString *)CPUArch isSystemInfoHeader:(BOOL)isSystemInfoHeader;

/** Determine the CPU architecture based on major/minor CPU architecture codes.
 *
 * @param majorCode The major part of the code.
 *
 * @param minorCode The minor part of the code.
 *
 * @return The CPU architecture.
 */
- (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode;

/** Take a UUID string and strip out all the dashes.
 *
 * @param uuid the UUID.
 *
 * @return the UUID in compact form.
 */
- (NSString *)toCompactUUID:(NSString *)uuid;

@end


@interface NSString (FTCrashCompareRegisterNames)

- (NSComparisonResult)ftcrash_compareRegisterName:(NSString *)other;

@end

@implementation NSString (FTCrashCompareRegisterNames)

- (NSComparisonResult)ftcrash_compareRegisterName:(NSString *)other
{
    BOOL containsNum = [self rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
    BOOL otherContainsNum =
        [other rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;

    if (containsNum && !otherContainsNum) {
        return NSOrderedAscending;
    } else if (!containsNum && otherContainsNum) {
        return NSOrderedDescending;
    } else {
        return [self localizedStandardCompare:other];
    }
}

@end

@implementation FTCrashReportWrapper
/** Date formatter for Apple date format in crash reports. */
static NSDateFormatter *g_dateFormatter;

/** Date formatter for RFC3339 date format. */
static NSDateFormatter *g_rfc3339DateFormatter;

/** Printing order for registers. */
static NSDictionary *g_registerOrders;

+ (void)initialize
{
    g_dateFormatter = [[NSDateFormatter alloc] init];
    [g_dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [g_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS ZZZ"];

    g_rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    [g_rfc3339DateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [g_rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSSSS'Z'"];
    [g_rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    NSArray *armOrder = [NSArray arrayWithObjects:@"r0", @"r1", @"r2", @"r3", @"r4", @"r5", @"r6", @"r7", @"r8", @"r9",
                                                  @"r10", @"r11", @"ip", @"sp", @"lr", @"pc", @"cpsr", nil];

    NSArray *x86Order = [NSArray arrayWithObjects:@"eax", @"ebx", @"ecx", @"edx", @"edi", @"esi", @"ebp", @"esp", @"ss",
                                                  @"eflags", @"eip", @"cs", @"ds", @"es", @"fs", @"gs", nil];

    NSArray *x86_64Order =
        [NSArray arrayWithObjects:@"rax", @"rbx", @"rcx", @"rdx", @"rdi", @"rsi", @"rbp", @"rsp", @"r8", @"r9", @"r10",
                                  @"r11", @"r12", @"r13", @"r14", @"r15", @"rip", @"rflags", @"cs", @"fs", @"gs", nil];

    g_registerOrders = [[NSDictionary alloc]
        initWithObjectsAndKeys:armOrder, @"arm", armOrder, @"armv6", armOrder, @"armv7", armOrder, @"armv7f", armOrder,
                               @"armv7k", armOrder, @"armv7s", x86Order, @"x86", x86Order, @"i386", x86Order, @"i486",
                               x86Order, @"i686", x86_64Order, @"x86_64", nil];
}

-(void)setEnableMemory:(BOOL)enableMemory{
    _enableMemory = enableMemory;
}
-(void)setEnableCpu:(BOOL)enableCpu{
    _enableCpu = enableCpu;
}
- (int)majorVersion:(NSDictionary *)report
{
    NSDictionary *info = [self infoReport:report];
    NSString *version = [info objectForKey:FTCrashField_Version];
    if ([version isKindOfClass:[NSDictionary class]]) {
        NSDictionary *oldVersion = (NSDictionary *)version;
        version = oldVersion[@"major"];
    }

    if ([version respondsToSelector:@selector(intValue)]) {
        return version.intValue;
    }
    return 0;
}
- (void)filterReports:(NSArray<id<FTCrashReport>> *)reports
         onCompletion:(nullable FTCrashReportFilterCompletion)onCompletion{
    NSMutableArray<id<FTCrashReport>> *filteredReports = [NSMutableArray arrayWithCapacity:[reports count]];
    for (FTCrashReportDictionary *report in reports) {
        if ([report isKindOfClass:[FTCrashReportDictionary class]] == NO) {
            FTInnerLogError(@"Unexpected non-dictionary report: %@", report);
            continue;
        }
        if ([self majorVersion:report.value] == kExpectedMajorVersion) {
            NSString *appleReportString = [self toAppleFormat:report.value];
            if (appleReportString == nil){
                continue;
            }
            
            NSDictionary *userInfo = report.value[FTCrashField_User];
            if (userInfo != nil) {
                FTFatalErrorContextModel *errorContext = [[FTFatalErrorContextModel alloc] initWithDict:userInfo];
                if(!errorContext.lastSessionState){
                    continue;
                }
                NSMutableDictionary *extra = [NSMutableDictionary new];
                NSString *registers = [self crashedThreadCPUStateStringForReport:report.value cpuArch:[self cpuArchForReport:report.value]];
                [extra setValue:registers forKey:@"registers"];
                
                RUMModel *errorModel = [RUMModel new];
                NSMutableDictionary *errorTags = [NSMutableDictionary dictionaryWithDictionary:errorContext.globalAttributes];
                
                [errorTags addEntriesFromDictionary:errorContext.dynamicContext];
                [errorTags addEntriesFromDictionary:errorContext.errorMonitorInfo];
                [errorTags addEntriesFromDictionary:[errorContext.lastSessionState sessionTags]];
                if (self.enableMemory) {
                    float memUsage = [self memoryUsageForReport:report.value];
                    [errorTags setValue:@(memUsage) forKey:FT_MEMORY_USE];
                }
                if (self.enableCpu) {
                    float cpuUsage = [self threadCpuUsageForReport:report.value];
                    [errorTags setValue:@(cpuUsage) forKey:FT_CPU_USE];
                }
                [errorTags setValue:FT_LOGGER forKey:FT_KEY_ERROR_SOURCE];
                [errorTags setValue:errorContext.appState forKey:FT_KEY_ERROR_SITUATION];
                
                NSMutableDictionary *errorFields = [NSMutableDictionary new];
                NSNumber *sessionErrorTimestamp = nil;
                if (errorContext.lastSessionState.sampled_for_error_session) {
                    errorContext.lastSessionState.session_error_timestamp = self.crashDate;
                    sessionErrorTimestamp = @(self.crashDate);
                }
                [errorFields addEntriesFromDictionary:[errorContext.lastSessionState sessionFields]];
                [errorFields setValue:@"ios_crash" forKey:FT_KEY_ERROR_TYPE];
                [errorFields setValue:self.crashMessage forKey:FT_KEY_ERROR_MESSAGE];
                [errorFields setValue:appleReportString forKey:FT_KEY_ERROR_STACK];
                [errorFields setValue:extra forKey:@"crash_extra"];
                errorModel.source = FT_RUM_SOURCE_ERROR;
                
                if(errorContext.lastViewContext){
                    NSString *viewId = errorContext.lastViewContext[@"tags"][FT_KEY_VIEW_ID];
                    NSString *viewName = errorContext.lastViewContext[@"tags"][FT_KEY_VIEW_NAME];

                    [errorTags setValue:viewId forKey:FT_KEY_VIEW_ID];
                    [errorTags setValue:viewName forKey:FT_KEY_VIEW_NAME];

                    long long time = [errorContext.lastViewContext[@"time"] longLongValue];
                    NSMutableDictionary *tags = [NSMutableDictionary dictionaryWithDictionary:errorContext.globalAttributes];
                    NSMutableDictionary *fields = [NSMutableDictionary new];
                    [tags addEntriesFromDictionary:errorContext.lastViewContext[@"tags"]];
                    [fields addEntriesFromDictionary:errorContext.lastViewContext[@"fields"]];
        
                    fields[FT_KEY_VIEW_ERROR_COUNT] = @([fields[FT_KEY_VIEW_ERROR_COUNT] intValue] + 1);
                    fields[FT_KEY_VIEW_UPDATE_TIME] = @([fields[FT_KEY_VIEW_UPDATE_TIME] intValue] + 1);
                    fields[FT_KEY_IS_ACTIVE] = @(NO);
                    fields[FT_KEY_TIME_SPENT] = @(self.crashDate - time);
                    fields[FT_SESSION_ERROR_TIMESTAMP] = sessionErrorTimestamp;
                    RUMModel *viewModel = [[RUMModel alloc]init];
                    viewModel.source = FT_RUM_SOURCE_VIEW;
                    viewModel.tags = tags;
                    viewModel.fields = fields;
                    viewModel.createTime = time;
                    [filteredReports addObject:[FTCrashReportRUMModel reportWithValue:viewModel]];
                }
                
                errorModel.tags = errorTags;
                errorModel.fields = errorFields;
                errorModel.createTime = self.crashDate;
                [filteredReports addObject:[FTCrashReportRUMModel reportWithValue:errorModel]];

            }
        }
        
    }
    ftcrash_callCompletion(onCompletion, filteredReports, nil);
}
#pragma mark ----- FTBacktraceReporting -----
-(NSString *)generateBacktrace:(thread_t)thread{
    FTCrashThread currentThread = ftcrashthread_self();
    FTCrashMachineContext context = { 0 };
    FTCrashStackEntry stackEntries[MAX_STACKTRACE_LENGTH] = {0};
    NSMutableString *threadStr = [NSMutableString string];
    NSMutableDictionary *imagesDict = [NSMutableDictionary new];
    int count = getStackEntriesFromThread(thread,&context,stackEntries,MAX_STACKTRACE_LENGTH,true,currentThread == thread);
    if (count>0)  {
        [self appendThreadInfoForThreadIndex:0 thread:thread stackEntries:stackEntries stackLength:count toMutableString:threadStr imagesDict:imagesDict];
        [self appendCommonTailToMutableString:threadStr imagesDict:imagesDict];
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
            int numberOfEntries = getStackEntriesFromThread(suspendedThreads[i], &context,
                    threadsInfos[i].stackEntries, MAX_STACKTRACE_LENGTH, true,suspendedThreads[i] == currentThread);
            threadsInfos[i].stackLength = numberOfEntries;
            
            threadsInfos[i].thread = suspendedThreads[i];
        }
        ftcrashmc_resumeEnvironment(&suspendedThreads, &numSuspendedThreads);
       
        NSMutableString *threadStr = [NSMutableString string];
        NSMutableDictionary *imagesDict = [NSMutableDictionary new];
        for (int i = 0; i < numThreads; i++) {
            int count = threadsInfos[i].stackLength;
            if (count>0) {
                [self appendThreadInfoForThreadIndex:i thread:threadsInfos[i].thread stackEntries:threadsInfos[i].stackEntries stackLength:count toMutableString:threadStr imagesDict:imagesDict];
            }
        }
        [self appendCommonTailToMutableString:threadStr imagesDict:imagesDict];
        return threadStr;
    }
    return nil;
}
- (void)appendThreadInfoForThreadIndex:(NSInteger)threadIndex
                                thread:(FTCrashThread)thread
                          stackEntries:(FTCrashStackEntry *)stackEntries
                           stackLength:(NSInteger)stackLength
                       toMutableString:(NSMutableString *)threadStr
                            imagesDict:(NSMutableDictionary *)imagesDict {

    [threadStr appendFormat:@"\nThread %ld:\n", threadIndex];

    for (int index = 0; index < stackLength; index++) {
        FTCrashStackEntry entry = stackEntries[index];
        if (entry.imageName) {
            NSString *imagePath = [NSString stringWithUTF8String:entry.imageName];
            NSString *imageName = [imagePath lastPathComponent];
            if (imageName == nil) {
                imageName = @"(null)";
            }
            NSString *preamble = [NSString stringWithFormat:FMT_TRACE_PREAMBLE, index, imageName.UTF8String, entry.address];
            NSString *unsymbolicated = [NSString stringWithFormat:FMT_TRACE_UNSYMBOLICATED, entry.imageAddress, entry.address - entry.imageAddress];
            NSString *symbolicated = nil;
            
            if (entry.symbolName) {
                NSString *symbolName = [NSString stringWithUTF8String:entry.symbolName];
                if (![symbolName isEqualToString:kAppleRedactedText]) {
                    symbolicated = [NSString stringWithFormat:FMT_TRACE_SYMBOLICATED, symbolName, entry.address - entry.symbolAddress];
                }
            }
            if (symbolicated) {
                [threadStr appendFormat:@"%@ %@",preamble,symbolicated];
            }else{
                [threadStr appendFormat:@"%@ %@",preamble,unsymbolicated];
            }
            if (!imagesDict[@(entry.imageAddress)]) {
                NSString *imageStr = [self binaryImageStringForImageAddress:entry.imageAddress imageName:entry.imageName];
                imagesDict[@(entry.imageAddress)] = imageStr;
            }
        } else {
            [threadStr appendFormat:@"%-4d ??? 0x%016llx 0x0 + 0", index, (unsigned long long)entry.address];
        }
        [threadStr appendString:@"\n"];
    }
}
- (NSString *)binaryImageStringForImageAddress:(uintptr_t)imageAddress imageName:(const char *)imageName {
    FTCrashBinaryImage image = {0};
    ftcrashdl_binaryImageForHeader((void *)imageAddress, imageName, &image);
    cpu_type_t cpuType = image.cpuType;
    cpu_subtype_t cpuSubtype = image.cpuSubType;
    uintptr_t imageAddr = image.address;
    uintptr_t imageSize = image.size;
    NSString *uuid = [self toCompactUUID:[[[NSUUID alloc] initWithUUIDBytes:image.uuid] UUIDString]];
    NSString *arch = [self CPUArchForMajor:cpuType minor:cpuSubtype];
    NSString *imagePath = [NSString stringWithUTF8String:imageName];
    NSString *imageFileName = [imagePath lastPathComponent];
    
    return [NSString stringWithFormat:@"  " FMT_PTR_RJ @" - " FMT_PTR_RJ @" %@ %@  <%@> %@",
            imageAddr, imageAddr + imageSize - 1, imageFileName, arch, uuid, imagePath];
}
- (void)appendCommonTailToMutableString:(NSMutableString *)threadStr imagesDict:(NSMutableDictionary *)imagesDict {
    [threadStr appendString:@"\nBinary Images:\n"];
    [threadStr appendString:[imagesDict.allValues componentsJoinedByString:@"\n"]];
    
    NSString *header = [self headStringForFreeze];
    [threadStr insertString:header atIndex:0];
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
#pragma mark -------- applefmt ---------
- (NSString *)toCompactUUID:(NSString *)uuid
{
    return [[uuid lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
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
- (NSString *)CPUArchForMajor:(cpu_type_t)majorCode minor:(cpu_subtype_t)minorCode
{
    // In Apple platforms we can use this function to get the name of a particular architecture
    const char *archName = ftcrashcpu_archForCPU(majorCode, minorCode);
    if (archName) {
        return [[NSString alloc] initWithUTF8String:archName];
    }

    switch (majorCode) {
        case CPU_TYPE_ARM: {
            switch (minorCode) {
                case CPU_SUBTYPE_ARM_V6:
                    return @"armv6";
                case CPU_SUBTYPE_ARM_V7:
                    return @"armv7";
                case CPU_SUBTYPE_ARM_V7F:
                    return @"armv7f";
                case CPU_SUBTYPE_ARM_V7K:
                    return @"armv7k";
#ifdef CPU_SUBTYPE_ARM_V7S
                case CPU_SUBTYPE_ARM_V7S:
                    return @"armv7s";
#endif
                default:
                    break;
            }
            return @"arm";
        }
        case CPU_TYPE_ARM64: {
            switch (minorCode) {
                case CPU_SUBTYPE_ARM64E:
                    return @"arm64e";
                default:
                    break;
            }
            return @"arm64";
        }
        case CPU_TYPE_X86:
            return @"i386";
        case CPU_TYPE_X86_64:
            return @"x86_64";
        default:
            return [NSString stringWithFormat:@"unknown(%d,%d)", majorCode, minorCode];
    }
}
/** Convert a backtrace to a string.
 *
 * @param backtrace The backtrace to convert.
 *
 * @param mainExecutableName Name of the app executable.
 *
 * @return The converted string.
 */
- (NSString *)backtraceString:(NSDictionary *)backtrace
           mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    int traceNum = 0;
    for (NSDictionary *trace in [backtrace objectForKey:FTCrashField_Contents]) {
        uintptr_t pc = (uintptr_t)[[trace objectForKey:FTCrashField_InstructionAddr] longLongValue];
        uintptr_t objAddr = (uintptr_t)[[trace objectForKey:FTCrashField_ObjectAddr] longLongValue];
        NSString *objName = [[trace objectForKey:FTCrashField_ObjectName] lastPathComponent];
        if (objName == nil) {
            objName = @"(null)";
        }
        uintptr_t symAddr = (uintptr_t)[[trace objectForKey:FTCrashField_SymbolAddr] longLongValue];
        NSString *symName = [trace objectForKey:FTCrashField_SymbolName];
      

        NSString *preamble = [NSString stringWithFormat:FMT_TRACE_PREAMBLE, traceNum, [objName UTF8String], pc];
        NSString *unsymbolicated = [NSString stringWithFormat:FMT_TRACE_UNSYMBOLICATED, objAddr, pc - objAddr];
        NSString *symbolicated = @"(null)";
        if ([symName isKindOfClass:[NSString class]]) {
            symbolicated = [NSString stringWithFormat:FMT_TRACE_SYMBOLICATED, symName, pc - symAddr];
        }

        // Apple has started replacing symbols for any function/method
        // beginning with an underscore with "<redacted>" in iOS 6.
        // No, I can't think of any valid reason to do this, either.
        if ([symName isEqualToString:kAppleRedactedText]) {
            [str appendFormat:@"%@ %@\n", preamble, unsymbolicated];
        }else{
            [str appendFormat:@"%@ %@\n", preamble, symbolicated];
        }
        traceNum++;
    }

    return str;
}
- (NSString *)stringFromDate:(NSDate *)date
{
    if (![date isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return [g_dateFormatter stringFromDate:date];
}

- (NSDictionary *)recrashReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_RecrashReport];
}
- (NSDictionary *)systemReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_System];
}

- (NSDictionary *)infoReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_Report];
}

- (NSDictionary *)processReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_ProcessState];
}
- (NSDictionary *)crashReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_Crash];
}
- (NSString *)binaryImagesStringForReport:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSArray *binaryImages = [self binaryImagesReport:report];

    [str appendString:@"\nBinary Images:\n"];
    if (binaryImages) {
        NSMutableArray *images = [NSMutableArray arrayWithArray:binaryImages];
        [images sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSNumber *num1 = [(NSDictionary *)obj1 objectForKey:FTCrashField_ImageAddress];
            NSNumber *num2 = [(NSDictionary *)obj2 objectForKey:FTCrashField_ImageAddress];
            if (num1 == nil || num2 == nil) {
                return NSOrderedSame;
            }
            return [num1 compare:num2];
        }];
        for (NSDictionary *image in images) {
            cpu_type_t cpuType = [[image objectForKey:FTCrashField_CPUType] intValue];
            cpu_subtype_t cpuSubtype = [[image objectForKey:FTCrashField_CPUSubType] intValue];
            uintptr_t imageAddr = (uintptr_t)[[image objectForKey:FTCrashField_ImageAddress] longLongValue];
            uintptr_t imageSize = (uintptr_t)[[image objectForKey:FTCrashField_ImageSize] longLongValue];
            NSString *path = [image objectForKey:FTCrashField_Name];
            NSString *name = [path lastPathComponent];
            NSString *uuid = [self toCompactUUID:[image objectForKey:FTCrashField_UUID]];
            NSString *arch = [self CPUArchForMajor:cpuType minor:cpuSubtype];
            [str appendFormat:FMT_PTR_RJ @" - " FMT_PTR_RJ @" %@ %@  <%@> %@\n", imageAddr, imageAddr + imageSize - 1,
                              name, arch, uuid, path];
        }
    }

    return str;
}
- (NSArray *)binaryImagesReport:(NSDictionary *)report
{
    return [report objectForKey:FTCrashField_BinaryImages];
}
- (NSString *)mainExecutableNameForReport:(NSDictionary *)report
{
    NSDictionary *info = [self infoReport:report];
    return [info objectForKey:FTCrashField_ProcessName];
}

- (NSString *)cpuArchForReport:(NSDictionary *)report
{
    NSDictionary *system = [self systemReport:report];
    cpu_type_t cpuType = [[system objectForKey:FTCrashField_BinaryCPUType] intValue];
    cpu_subtype_t cpuSubType = [[system objectForKey:FTCrashField_BinaryCPUSubType] intValue];
    return [self CPUArchForMajor:cpuType minor:cpuSubType];
}
- (NSString *)headerStringForReport:(NSDictionary *)report
{
    NSDictionary *system = [self systemReport:report];
    NSDictionary *reportInfo = [self infoReport:report];
    NSString *reportID = [reportInfo objectForKey:FTCrashField_ID];
    NSDate *crashTime = [g_rfc3339DateFormatter dateFromString:[reportInfo objectForKey:FTCrashField_Timestamp]];
    self.crashDate = [crashTime ft_nanosecondTimeStamp];
    return [self headerStringForSystemInfo:system reportID:reportID crashTime:crashTime];
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

    [str appendFormat:@"Incident Identifier: %@\n", reportID];
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
    [str appendFormat:@"Date/Time:           %@\n", [self stringFromDate:crashTime]];
    [str appendFormat:@"OS Version:          %@ %@ (%@)\n", [system objectForKey:FTCrashField_SystemName],
                      [system objectForKey:FTCrashField_SystemVersion], [system objectForKey:FTCrashField_OSVersion]];
    [str appendFormat:@"Report Version:      104\n"];

    return str;
}
- (NSDictionary *)crashedThread:(NSDictionary *)report
{
    NSDictionary *crash = [self crashReport:report];
    NSArray *threads = [crash objectForKey:FTCrashField_Threads];
    for (NSDictionary *thread in threads) {
        BOOL crashed = [[thread objectForKey:FTCrashField_Crashed] boolValue];
        if (crashed) {
            return thread;
        }
    }

    return [crash objectForKey:FTCrashField_CrashedThread];
}
- (NSString *)crashedThreadCPUStateStringForReport:(NSDictionary *)report cpuArch:(NSString *)cpuArch
{
    NSDictionary *thread = [self crashedThread:report];
    if (thread == nil) {
        return @"";
    }
    int threadIndex = [[thread objectForKey:FTCrashField_Index] intValue];

    NSString *cpuArchType = [self CPUType:cpuArch isSystemInfoHeader:NO];

    NSMutableString *str = [NSMutableString string];

    [str appendFormat:@"\nThread %d crashed with %@ Thread State:\n", threadIndex, cpuArchType];

    NSDictionary *registers =
        [(NSDictionary *)[thread objectForKey:FTCrashField_Registers] objectForKey:FTCrashField_Basic];
    NSArray *regOrder = [g_registerOrders objectForKey:cpuArch];
    if (regOrder == nil) {
        regOrder = [[registers allKeys] sortedArrayUsingSelector:@selector(ftcrash_compareRegisterName:)];
    }
    NSUInteger numRegisters = [regOrder count];
    NSUInteger i = 0;
    while (i < numRegisters) {
        NSUInteger nextBreak = i + 4;
        if (nextBreak > numRegisters) {
            nextBreak = numRegisters;
        }
        for (; i < nextBreak; i++) {
            NSString *regName = [regOrder objectAtIndex:i];
            uintptr_t addr = (uintptr_t)[[registers objectForKey:regName] longLongValue];
            [str appendFormat:@"%6s: " FMT_PTR_LONG @" ", [regName cStringUsingEncoding:NSUTF8StringEncoding], addr];
        }
        [str appendString:@"\n"];
    }

    return str;
}

- (NSString *)JSONForObject:(id)object
{
    NSError *error = nil;
    NSData *encoded = [FTCrashJSONCodec encode:object
                                  options:FTCrashJSONEncodeOptionPretty | FTCrashJSONEncodeOptionSorted
                                    error:&error];
    if (error != nil) {
        return [NSString stringWithFormat:@"Error encoding JSON: %@", error];
    } else {
        return [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
    }
}

- (NSString *)errorInfoStringForReport:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *thread = [self crashedThread:report];
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *error = [crash objectForKey:FTCrashField_Error];
    NSDictionary *type = [error objectForKey:FTCrashField_Type];

    NSDictionary *nsexception = [error objectForKey:FTCrashField_NSException];
    NSDictionary *cppexception = [error objectForKey:FTCrashField_CPPException];
    NSDictionary *mach = [error objectForKey:FTCrashField_Mach];
    NSDictionary *signal = [error objectForKey:FTCrashField_Signal];

    NSString *machExcName = [mach objectForKey:FTCrashField_ExceptionName];
    if (machExcName == nil) {
        machExcName = @"0";
    }
    NSString *signalName = [signal objectForKey:FTCrashField_Name];
    if (signalName == nil) {
        signalName = [[signal objectForKey:FTCrashField_Signal] stringValue];
    }
    NSString *machCodeName = [mach objectForKey:FTCrashField_CodeName];
    if (machCodeName == nil) {
        machCodeName = @"0x00000000";
    }

    [str appendFormat:@"\n"];
    [str appendFormat:@"Exception Type:  %@ (%@)\n", machExcName, signalName];
    [str appendFormat:@"Exception Codes: %@ at " FMT_PTR_LONG @"\n", machCodeName,
                      (uintptr_t)[[error objectForKey:FTCrashField_Address] longLongValue]];
    self.crashMessage = [NSString stringWithFormat:@"Exception Type:  %@ (%@)\nException Codes: %@ at " FMT_PTR_LONG, machExcName, signalName,machCodeName,
                         (uintptr_t)[[error objectForKey:FTCrashField_Address] longLongValue]];
    [str appendFormat:@"Triggered by Thread:  %d\n", [[thread objectForKey:FTCrashField_Index] intValue]];

    if (nsexception != nil) {
        NSString *message = [self stringWithUncaughtExceptionName:[nsexception objectForKey:FTCrashField_Name]
                                                           reason:[error objectForKey:FTCrashField_Reason]];
        [str appendString:message];
        self.crashMessage = message;
    } else if ([type isEqual:FTCrashExcType_CPPException]) {
        NSString *message = [self stringWithUncaughtExceptionName:[cppexception objectForKey:FTCrashField_Name]
                                                           reason:[error objectForKey:FTCrashField_Reason]];
        [str appendString:message];
        self.crashMessage = message;
    }
    return str;
}

- (NSString *)stringWithUncaughtExceptionName:(NSString *)name reason:(NSString *)reason
{
    return [NSString stringWithFormat:@"\nApplication Specific Information:\n"
                                      @"*** Terminating app due to uncaught exception '%@', reason: '%@'\n",
                                      name, reason];
}

- (NSString *)threadStringForThread:(NSDictionary *)thread mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    [str appendFormat:@"\n"];
    BOOL crashed = [[thread objectForKey:FTCrashField_Crashed] boolValue];
    int index = [[thread objectForKey:FTCrashField_Index] intValue];
    NSString *name = [thread objectForKey:FTCrashField_Name];
    NSString *queueName = [thread objectForKey:FTCrashField_DispatchQueue];

    if (name != nil) {
        [str appendFormat:@"Thread %d name:  %@\n", index, name];
    } else if (queueName != nil) {
        [str appendFormat:@"Thread %d name:  Dispatch queue: %@\n", index, queueName];
    }

    if (crashed) {
        [str appendFormat:@"Thread %d Crashed:\n", index];
    } else {
        [str appendFormat:@"Thread %d:\n", index];
    }

    [str appendString:[self backtraceString:[thread objectForKey:FTCrashField_Backtrace]
                          mainExecutableName:mainExecutableName]];

    return str;
}

- (NSString *)threadListStringForReport:(NSDictionary *)report mainExecutableName:(NSString *)mainExecutableName
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *crash = [self crashReport:report];
    NSArray *threads = [crash objectForKey:FTCrashField_Threads];

    for (NSDictionary *thread in threads) {
        [str appendString:[self threadStringForThread:thread mainExecutableName:mainExecutableName]];
    }

    return str;
}
- (NSString *)crashReportString:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];
    NSString *executableName = [self mainExecutableNameForReport:report];

    [str appendString:[self headerStringForReport:report]];
    [str appendString:[self errorInfoStringForReport:report]];
    [str appendString:[self threadListStringForReport:report mainExecutableName:executableName]];
//    [str appendString:[self crashedThreadCPUStateStringForReport:report cpuArch:[self cpuArchForReport:report]]];
    [str appendString:[self binaryImagesStringForReport:report]];
//    [str appendString:[self extraInfoStringForReport:report mainExecutableName:executableName]];

    return str;
}
- (float)threadCpuUsageForReport:(NSDictionary *)report{
    NSDictionary *crash = [self crashReport:report];
    NSArray *threads = [crash objectForKey:FTCrashField_Threads];
    float tot_cpu = 0;

    for (NSDictionary *thread in threads) {
        NSNumber *cpuUsage = thread[FTCrashField_CPU];
        if (cpuUsage) {
            tot_cpu = tot_cpu + [cpuUsage floatValue];
        }
    }
    return (tot_cpu / [NSProcessInfo processInfo].processorCount) * 100.0f;
}
- (float)memoryUsageForReport:(NSDictionary *)report{
    NSDictionary *system = [self systemReport:report];
    NSDictionary *memory = system[FTCrashField_Memory];
    NSNumber *memorySize = memory[FTCrashField_Size];
    NSNumber *memoryAvailable = memory[FTCrashField_Available];
    if (memoryAvailable && memorySize) {
        NSUInteger total = [memorySize unsignedIntegerValue];
        NSUInteger avail = [memoryAvailable unsignedIntegerValue];
        float usage =  (float)(total - avail) / total * 100;
        return MAX(0.0f, MIN(100.0f, usage));
    }
    return 0.0f;
}
- (NSString *)recrashReportString:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

    NSDictionary *recrashReport = [self recrashReport:report];
    NSDictionary *system = [self systemReport:recrashReport];
    NSString *executablePath = [system objectForKey:FTCrashField_ExecutablePath];
    NSString *executableName = [executablePath lastPathComponent];
    NSDictionary *crash = [self crashReport:report];
    NSDictionary *thread = [crash objectForKey:FTCrashField_CrashedThread];

    [str appendString:@"\nHandler crashed while reporting:\n"];
    [str appendString:[self errorInfoStringForReport:report]];
    [str appendString:[self threadStringForThread:thread mainExecutableName:executableName]];
//    [str appendString:[self crashedThreadCPUStateStringForReport:report cpuArch:[self cpuArchForReport:recrashReport]]];
    NSString *diagnosis = [crash objectForKey:FTCrashField_Diagnosis];
    if (diagnosis != nil) {
        [str appendFormat:@"\nRecrash Diagnosis: %@", diagnosis];
    }

    return str;
}
- (NSString *)toAppleFormat:(NSDictionary *)report
{
    NSMutableString *str = [NSMutableString string];

//    NSDictionary *recrashReport = report[FTCrashField_RecrashReport];
//    if (recrashReport) {
//        [str appendString:[self crashReportString:recrashReport]];
//        [str appendString:[self recrashReportString:report]];
//    } else {
    [str appendString:[self crashReportString:report]];
//    }

    return str;
}
@end

