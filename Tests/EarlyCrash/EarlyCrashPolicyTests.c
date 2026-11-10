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

#include "FTEarlyCrash.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <pthread.h>

#define START UINT64_C(100000000000)
static FTEarlyCrashState *launch(const char *path) {
    FTEarlyCrashState *state = ft_earlyCrashCreate();
    assert(state);
    ft_earlyCrashInitialize(state, START, path);
    return state;
}
static void runLaunch(const char *program, const char *path, const char *expected, const char *elapsed) {
    pid_t pid = fork();
    assert(pid >= 0);
    if (!pid) {
        execl(program, program, "--launch", path, expected, elapsed, NULL);
        _exit(99);
    }
    int status;
    assert(waitpid(pid, &status, 0) == pid);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
}
static void testDelayedPreparation(const char *path) {
    FTEarlyCrashState *state = ft_earlyCrashCreate(); assert(state);
    ft_earlyCrashStartInState(state, START);
    // The event occurs within five seconds; preparation is delayed past it.
    ft_earlyCrashRecordInState(state, START + UINT64_C(4999000000));
    assert(access(path, F_OK) != 0); // start capture and pending event do no I/O
    assert(ft_earlyCrashTakeDelayInState(state) == 10); // must not consume allowance
    ft_earlyCrashInitialize(state, START + UINT64_C(9000000000), path);
    ft_earlyCrashDestroy(state);
    state = launch(path);
    assert(ft_earlyCrashTakeDelayInState(state) == 2);
    assert(ft_earlyCrashTakeDelayInState(state) == 10);
    ft_earlyCrashDestroy(state);
    unlink(path);
    state = ft_earlyCrashCreate(); assert(state);
    ft_earlyCrashStartInState(state, START);
    ft_earlyCrashStartInState(state, START + UINT64_C(9000000000));
    ft_earlyCrashRecordInState(state, START + UINT64_C(5001000000));
    ft_earlyCrashInitialize(state, START + UINT64_C(9000000000), path);
    ft_earlyCrashDestroy(state);
    state = launch(path);
    assert(ft_earlyCrashTakeDelayInState(state) == 10); // processing time is irrelevant
    ft_earlyCrashDestroy(state);
    unlink(path);
}
static void *recordWhilePreparing(void *context) {
    FTEarlyCrashState *state = context;
    for (unsigned i = 0; i < 100; i++)
        ft_earlyCrashRecordInState(state, START + UINT64_C(4999000000));
    return NULL;
}
static void testConcurrentPreparation(const char *path) {
    for (unsigned i = 0; i < 100; i++) {
        FTEarlyCrashState *state = ft_earlyCrashCreate(); assert(state);
        ft_earlyCrashStartInState(state, START);
        pthread_t thread;
        assert(pthread_create(&thread, NULL, recordWhilePreparing, state) == 0);
        ft_earlyCrashInitialize(state, START, path);
        assert(pthread_join(thread, NULL) == 0);
        ft_earlyCrashDestroy(state);
        state = launch(path);
        assert(ft_earlyCrashTakeDelayInState(state) == 2);
        ft_earlyCrashDestroy(state);
        unlink(path);
    }
}
int main(int argc, char **argv) {
    if (argc == 5 && !strcmp(argv[1], "--launch")) {
        ft_earlyCrashBegin(START, argv[2]);
        ft_earlyCrashRecord(START + 1);
        assert(ft_earlyCrashTakeUploadDelay() == 10); // macOS facade stays disabled
        FTEarlyCrashState *state = launch(argv[2]);
        assert(ft_earlyCrashTakeDelayInState(state) == (unsigned)atoi(argv[3]));
        if (strcmp(argv[4], "normal")) {
            ft_earlyCrashRecordInState(state, START + strtoull(argv[4], NULL, 10));
        }
        // Crash-like termination: no explicit close, destructor, or normal cleanup.
        _exit(0);
    }
    char directory[] = "/tmp/ft-early-crash-XXXXXX";
    assert(mkdtemp(directory));
    char path[1024];
    snprintf(path, sizeof(path), "%s/EarlyCrash.marker", directory);
    testDelayedPreparation(path);
    testConcurrentPreparation(path);
    // Independent processes, not just reconstructed objects: A crash -> B normal -> C normal.
    runLaunch(argv[0], path, "10", "4999000000");
    runLaunch(argv[0], path, "2", "normal");
    runLaunch(argv[0], path, "10", "normal");
    // A/B crash -> B/C shortened -> C normal -> D normal.
    runLaunch(argv[0], path, "10", "5000000000");
    runLaunch(argv[0], path, "2", "4999000000");
    runLaunch(argv[0], path, "2", "normal");
    runLaunch(argv[0], path, "10", "normal");
    unlink(path); rmdir(directory);
    puts("Early crash process integration: 7 fresh-process launches and macOS facade guard passed");
}
