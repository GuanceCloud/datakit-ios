//
//  EarlyCrashPolicyTests.c
//  FTMobileSDK
//
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

#include "FTCrashMonitor_AppState.h"
#include "FTCrashC.h"
#include "FTCrashMonitorContext.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#define START UINT64_C(100000000000)
static uint64_t sdkOrigin = START;
uint64_t ft_earlyCrashTestSDKStart(void) { return sdkOrigin; }
static const char *callbackPath;
static uint64_t expectedDuration, processingTime;
static void delayedCallback(FTCrash_ExceptionHandlingPlan *plan, const FTCrash_MonitorContext *context) {
    (void)plan;
    FTCrash_AppState snapshot;
    assert(ftcrashstate_readPersistedState(callbackPath, &snapshot));
    assert(snapshot.previousEarlyCrash == (expectedDuration <= UINT64_C(5000000000)));
    assert(snapshot.previousEarlyCrashDurationNS == expectedDuration);
    processingTime = context->earlyCrashTime + UINT64_C(60000000000);
}

static void run(const char *program, const char *path, const char *expected, const char *event) {
    pid_t pid = fork(); assert(pid >= 0);
    if (!pid) { execl(program, program, "--launch", path, expected, event, NULL); _exit(99); }
    int status; assert(waitpid(pid, &status, 0) == pid);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
}
int main(int argc, char **argv) {
    if (argc == 5) {
        if (!strcmp(argv[4], "disabled")) _exit(0); // no state read or consumption
        ftcrashstate_notifyObjCLoad();
        ftcrashstate_initialize(argv[2]);
        ftcrashcm_appstate_getAPI()->setEnabled(true);
        unsigned actual = ftcrashstate_currentState()->previousEarlyCrash ? 2 : 10;
        fprintf(stderr, "CrashState restore: expected=%s actual=%u\n", argv[3], actual);
        assert(actual == (unsigned)atoi(argv[3]));
        if (strcmp(argv[4], "normal")) {
            uint64_t event = START + strtoull(argv[4], NULL, 10);
            FTCrash_MonitorContext context = {0};
            context.earlyCrashTime = START + UINT64_C(1000000000);
            context.requirements.shouldWriteReport = true;
            assert(ftcrash_prepareEventForRecording(&context)); // nonfatal
            context.requirements.isFatal = true;
            context.currentSnapshotUserReported = true;
            assert(ftcrash_prepareEventForRecording(&context)); // manual report
            context.currentSnapshotUserReported = false;
            context.requirements.shouldWriteReport = false;
            assert(!ftcrash_prepareEventForRecording(&context)); // report disabled
            context.requirements.shouldWriteReport = true;
            context.earlyCrashTime = 0;
            assert(ftcrash_prepareEventForRecording(&context)); // missing capture
            context.earlyCrashTime = event; sdkOrigin = 0;
            assert(ftcrash_prepareEventForRecording(&context)); // missing origin
            sdkOrigin = START;
            FTCrash_AppState clean;
            assert(ftcrashstate_readPersistedState(argv[2], &clean));
            assert(!clean.previousEarlyCrash);
            bool early = event - START <= UINT64_C(5000000000);
            callbackPath = argv[2]; expectedDuration = early ? event - START : UINT64_MAX;
            ftcrash_setWillWriteCrashNotifyCallback(delayedCallback);
            assert(ftcrash_prepareEventForRecording(&context));
            ftcrash_setWillWriteCrashNotifyCallback(NULL);
            assert(context.earlyCrashTime == event);
            assert(processingTime == event + UINT64_C(60000000000));
            ftcrashstate_notifyAppCrash();
            if (early) {
                // Processing/duplicates arrive later, but cannot replace the
                // captured duration or turn this launch into its own history.
                assert(!ftcrashstate_recordEarlyCrash(START, START + UINT64_C(9000000000)));
                assert(ftcrashstate_recordEarlyCrash(START, START + UINT64_C(5000000000)));
                ftcrashstate_initialize(argv[2]);
                FTCrash_AppState persisted;
                assert(ftcrashstate_readPersistedState(argv[2], &persisted));
                assert(persisted.previousEarlyCrash);
                assert(persisted.previousEarlyCrashDurationNS == event - START);
            }
        }
        _exit(0); // No marker preparation, queue drain, or normal cleanup.
    }
    char directory[] = "/tmp/ft-crash-state-XXXXXX"; assert(mkdtemp(directory));
    char path[1024]; snprintf(path, sizeof(path), "%s/CrashState.json", directory);
    run(argv[0], path, "10", "1000000000");
    run(argv[0], path, "2", "normal");
    run(argv[0], path, "10", "normal");
    run(argv[0], path, "10", "4999000000");
    run(argv[0], path, "2", "5000000000");
    run(argv[0], path, "2", "normal");
    run(argv[0], path, "10", "normal");
    run(argv[0], path, "10", "5001000000");
    run(argv[0], path, "10", "normal");
    run(argv[0], path, "10", "4999000000");
    run(argv[0], path, "10", "disabled");
    run(argv[0], path, "2", "normal");
    run(argv[0], path, "10", "normal");
    unlink(path); rmdir(directory);
    puts("CrashState early-crash integration: 13 fresh-process launches passed");
}
