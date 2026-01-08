//
//  FTCrashReportStore.m
//
//  Created by Nikolay Volosatov on 2024-08-28.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "FTCrashReportStore.h"

#import "FTCrashReport.h"
#import "FTCrashReportFields.h"
#import "FTCrashReportFilter.h"
#import "FTCrashReportStoreC.h"
#import "FTCrashJSONCodecObjC.h"
#import "FTCrashNSErrorHelper.h"

#import "FTLog+Private.h"

@implementation FTCrashReportStore

+ (NSString *)defaultInstallSubfolder
{
    return @FTCRASHCRS_DEFAULT_REPORTS_FOLDER;
}

- (NSInteger)reportCount
{
    return ftcrashcrs_getReportCount();
}

- (void)sendAllReportsWithCompletion:(FTCrashReportFilterCompletion)onCompletion
{
    NSArray *reports = [self allReports];
    
    __weak __typeof(self) weakSelf = self;
    [self sendReports:reports
         onCompletion:^(NSArray *filteredReports, NSError *error) {
             FTInnerLogDebug(@"Process finished");
             if (error != nil) {
                 FTInnerLogError(@"Failed to send reports: %@", error);
             }
             if ((weakSelf.reportCleanupPolicy == FTCrashReportCleanupPolicyOnSuccess && error == nil) ||
                 weakSelf.reportCleanupPolicy == FTCrashReportCleanupPolicyAlways) {
                 [weakSelf deleteAllReports];
             }
             ftcrash_callCompletion(onCompletion, filteredReports, error);
         }];
    
}


- (void)deleteAllReports
{
    ftcrashcrs_deleteAllReports();
}

- (void)deleteReportWithID:(int64_t)reportID
{
    ftcrashcrs_deleteReportWithID(reportID);
}

#pragma mark - Private API

- (void)sendReports:(NSArray<id<FTCrashReport>> *)reports onCompletion:(FTCrashReportFilterCompletion)onCompletion
{
    if ([reports count] == 0) {
        ftcrash_callCompletion(onCompletion, reports, nil);
        return;
    }

    if (self.sink == nil) {
        ftcrash_callCompletion(onCompletion, reports,
                               [FTCrashNSErrorHelper errorWithDomain:[[self class] description]
                                                           code:0
                                                    description:@"No sink set. Crash reports not sent."]);
        return;
    }

    [self.sink filterReports:reports
                onCompletion:^(NSArray *filteredReports, NSError *error) {
                    ftcrash_callCompletion(onCompletion, filteredReports, error);
                }];
}

- (NSData *)loadCrashReportJSONWithID:(int64_t)reportID
{
    char *report = ftcrashcrs_readReport(reportID);
    if (report != NULL) {
        return [NSData dataWithBytesNoCopy:report length:strlen(report) freeWhenDone:YES];
    }
    return nil;
}

- (NSArray<NSNumber *> *)reportIDs
{
    int reportCount = ftcrashcrs_getReportCount();
    if (reportCount <= 0) {
        return @[];
    }
    int64_t *reportIDsC = malloc(sizeof(int64_t) * (size_t)reportCount);
    if (!reportIDsC) {
        return @[];
    }
    reportCount = ftcrashcrs_getReportIDs(reportIDsC, reportCount);
    NSMutableArray *reportIDs = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for (int i = 0; i < reportCount; i++) {
        [reportIDs addObject:[NSNumber numberWithLongLong:reportIDsC[i]]];
    }
    free(reportIDsC);
    return [reportIDs copy];
}

- (FTCrashReportDictionary *)reportForID:(int64_t)reportID
{
    NSData *jsonData = [self loadCrashReportJSONWithID:reportID];
    if (jsonData == nil) {
        return nil;
    }

    NSError *error = nil;
    NSMutableDictionary *crashReport =
        [FTCrashJSONCodec decode:jsonData
                    options:FTCrashJSONDecodeOptionIgnoreNullInArray | FTCrashJSONDecodeOptionIgnoreNullInObject |
         FTCrashJSONDecodeOptionKeepPartialObject
                      error:&error];
    if (error != nil) {
        FTInnerLogError(@"Encountered error loading crash report %" PRIx64 ": %@", reportID, error);
    }
    if (crashReport == nil) {
        FTInnerLogError(@"Could not load crash report");
        return nil;
    }

    return [FTCrashReportDictionary reportWithValue:crashReport];
}

- (NSArray<FTCrashReportDictionary *> *)allReports
{
    int reportCount = ftcrashcrs_getReportCount();
    int64_t reportIDs[reportCount];
    reportCount = ftcrashcrs_getReportIDs(reportIDs, reportCount);
    NSMutableArray<FTCrashReportDictionary *> *reports = [NSMutableArray arrayWithCapacity:(NSUInteger)reportCount];
    for (int i = 0; i < reportCount; i++) {
        FTCrashReportDictionary *report = [self reportForID:reportIDs[i]];
        if (report != nil) {
            [reports addObject:report];
        }
    }

    return reports;
}

@end

