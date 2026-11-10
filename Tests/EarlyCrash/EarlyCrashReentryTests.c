//
//  EarlyCrashReentryTests.c
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
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

static pthread_mutex_t gate = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t arrived = PTHREAD_COND_INITIALIZER;
static unsigned writes;
static int mode;
static int firstPaused;
static FTEarlyCrashState *state;

// Only FTEarlyCrash.c is compiled with pwrite redirected to this test hook.
ssize_t ft_earlyCrashTestWrite(int fd, const void *bytes, size_t count, off_t offset) {
    pthread_mutex_lock(&gate);
    unsigned call = ++writes;
    if (call == 1 && mode == 1) {
        pthread_mutex_unlock(&gate);
        errno = EINTR;
        return -1;
    }
    if (call == 1 && mode == 0) {
        firstPaused = 1;
        pthread_cond_signal(&arrived);
        // The first handler stays suspended until process exit. Never sleep.
        for (;;) pthread_cond_wait(&arrived, &gate);
    }
    pthread_mutex_unlock(&gate);
    if ((call == 1 && mode == 2) || (call == 2 && mode == 3))
        return pwrite(fd, bytes, count / 2, offset);
    return pwrite(fd, bytes, count, offset);
}
static void *firstCrash(void *unused) {
    (void)unused;
    ft_earlyCrashRecordInState(state, UINT64_C(104999000000));
    return NULL;
}
static void runScenario(const char *path, int scenario) {
    pid_t child = fork(); assert(child >= 0);
    if (!child) {
        mode = scenario;
        state = ft_earlyCrashCreate(); assert(state);
        ft_earlyCrashInitialize(state, UINT64_C(100000000000), path);
        if (mode == 0) {
            pthread_t thread;
            assert(pthread_create(&thread, NULL, firstCrash, NULL) == 0);
            pthread_mutex_lock(&gate);
            while (!firstPaused) pthread_cond_wait(&arrived, &gate);
            pthread_mutex_unlock(&gate);
        } else {
            firstCrash(NULL);
        }
        // Another eligible occurrence at exactly five seconds must persist even
        // if the first writer never resumes, or its write was interrupted.
        ft_earlyCrashRecordInState(state, UINT64_C(105000000000));
        _exit(0);
    }
    int status;
    assert(waitpid(child, &status, 0) == child);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    FTEarlyCrashState *next = ft_earlyCrashCreate(); assert(next);
    ft_earlyCrashInitialize(next, UINT64_C(200000000000), path);
    unsigned delay = ft_earlyCrashTakeDelayInState(next);
    fprintf(stderr, "scenario=%s: next launch wait=%u, expected=2\n",
            scenario == 0 ? "first writer suspended" :
            (scenario == 1 ? "first write interrupted" :
             (scenario == 2 ? "first write partial" : "duplicate write partial")), delay);
    assert(delay == 2);
    assert(ft_earlyCrashTakeDelayInState(next) == 10);
    ft_earlyCrashDestroy(next);
}
int main(int argc, char **argv) {
    (void)argv;
    char directory[] = "/tmp/ft-early-reentry-XXXXXX";
    assert(mkdtemp(directory));
    char path[512]; snprintf(path, sizeof(path), "%s/marker", directory);
    // All cases terminate the writer process without cleanup, then recover in
    // a different process. Ordinary policy/idempotency checks live in XCTest.
    if (argc > 1) runScenario(path, 1);
    else { for (int scenario = 0; scenario < 4; scenario++) runScenario(path, scenario); }
    unlink(path); rmdir(directory);
    puts("Early crash process integration: suspended/interrupted/partial writes survive abrupt writer exit");
}
