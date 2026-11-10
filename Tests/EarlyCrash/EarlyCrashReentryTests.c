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

#include "FTCrashMonitor_AppState.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
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
static int resumeFirst;
static int armed;

// Only FTCrashFileUtils.c redirects write to this hook; production JSON encoding is unchanged.
ssize_t ft_earlyCrashTestWrite(int fd, const void *bytes, size_t count) {
    if (!armed) return write(fd, bytes, count);
    pthread_mutex_lock(&gate);
    unsigned call = ++writes;
    if (call == 1 && (mode == 1 || mode == 5)) {
        pthread_mutex_unlock(&gate);
        errno = mode == 5 ? EIO : EINTR;
        return -1;
    }
    if (call == 1 && (mode == 0 || mode == 4)) {
        firstPaused = 1;
        pthread_cond_signal(&arrived);
        // The first handler stays suspended until process exit. Never sleep.
        while (!resumeFirst) pthread_cond_wait(&arrived, &gate);
    }
    pthread_mutex_unlock(&gate);
    if ((call == 1 && mode == 2) || (call == 2 && mode == 3))
        return write(fd, bytes, count / 2);
    return write(fd, bytes, count);
}
static void *firstCrash(void *unused) {
    (void)unused;
    ftcrashstate_recordEarlyCrash(UINT64_C(100000000000), UINT64_C(104999000000));
    return NULL;
}
static void *ordinarySave(void *unused) {
    (void)unused;
    ftcrashstate_notifyAppTerminate();
    return NULL;
}
static void runScenario(const char *path, int scenario) {
    pid_t child = fork(); assert(child >= 0);
    if (!child) {
        mode = scenario;
        if (mode == 5) {
            const char history[] = "{\"version\":1,\"previousEarlyCrash\":true,\"earlyCrashDurationNS\":1000000000}";
            int file = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0600); assert(file >= 0);
            assert(write(file, history, sizeof(history) - 1) == sizeof(history) - 1); close(file);
        }
        ftcrashstate_notifyObjCLoad();
        ftcrashstate_initialize(path);
        armed = mode == 5;
        ftcrashcm_appstate_getAPI()->setEnabled(true);
        if (mode == 5) {
            assert(!ftcrashstate_currentState()->previousEarlyCrash);
            _exit(0); // failed history consumption cannot grant acceleration
        }
        armed = 1;
        pthread_t thread;
        if (mode == 0 || mode == 4) {
            assert(pthread_create(&thread, NULL, mode == 4 ? ordinarySave : firstCrash, NULL) == 0);
            pthread_mutex_lock(&gate);
            while (!firstPaused) pthread_cond_wait(&arrived, &gate);
            pthread_mutex_unlock(&gate);
        } else {
            firstCrash(NULL);
        }
        // Another eligible occurrence at exactly five seconds must persist even
        // if the first writer never resumes, or its write was interrupted.
        ftcrashstate_recordEarlyCrash(UINT64_C(100000000000),
            mode == 4 ? UINT64_C(104999000000) : UINT64_C(105000000000));
        if (mode == 4) {
            pthread_mutex_lock(&gate);
            resumeFirst = 1; pthread_cond_signal(&arrived);
            pthread_mutex_unlock(&gate);
            assert(pthread_join(thread, NULL) == 0);
        }
        _exit(0);
    }
    int status;
    assert(waitpid(child, &status, 0) == child);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    if (scenario == 5) {
        puts("CrashState failed history consumption: default wait preserved");
        return;
    }
    FTCrash_AppState next = {0};
    assert(ftcrashstate_readPersistedState(path, &next));
    unsigned delay = next.previousEarlyCrash ? 2 : 10;
    fprintf(stderr, "CrashState writer scenario=%d: next wait=%u, expected=2\n", scenario, delay);
    assert(delay == 2);
    assert(next.previousEarlyCrashDurationNS == UINT64_C(4999000000));

}
int main(int argc, char **argv) {
    (void)argv;
    char directory[] = "/tmp/ft-early-reentry-XXXXXX";
    assert(mkdtemp(directory));
    char path[512]; snprintf(path, sizeof(path), "%s/CrashState.json", directory);
    // All cases terminate the writer process without cleanup, then recover in
    // a different process. Ordinary policy/idempotency checks live in XCTest.
    if (argc > 1) runScenario(path, 1);
    else { for (int scenario = 0; scenario < 6; scenario++) runScenario(path, scenario); }
    unlink(path); rmdir(directory);
    puts("CrashState integration: 6 interrupted, partial, stale-write and I/O-failure scenarios passed");
}
