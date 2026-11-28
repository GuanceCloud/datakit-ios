//
//  CrashHandlerReinstallTests.m
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

#import <Foundation/Foundation.h>
#include "FTCrashLogger.h"
#include "FTCrashMachineContext.h"
#include "FTCrashMonitorAPI.h"
#include "FTCrashMonitor_MachException.h"
#include "FTCrashMonitor_NSException.h"
#include "FTCrashMonitor_Signal.h"
#include "FTCrashStackCursor_Backtrace.h"
#include "FTCrashStackCursor_MachineContext.h"
#include "FTCrashStackCursor_SelfThread.h"
#include "FTCrashThread.h"
#include <assert.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

// 采集相关的辅助函数不在测试范围内：这里只验证处理器的调用顺序和进程能否正常结束。
uint64_t ft_earlyCrashNow(void) { return 0; }
void ft_asyncLogC(int levelType, const char *level, const char *file, const char *function, int line, const char *fmt, ...)
{
    (void)levelType; (void)level; (void)file; (void)function; (void)line; (void)fmt;
}
FTCrashMonitorAPI *ftcrashcm_machexception_getAPI(void)
{
    static FTCrashMonitorAPI api = { 0 };
    ftcrashcma_initAPI(&api);
    return &api;
}
bool ftcrashmc_getContextForSignal(void *userContext, struct FTCrashMachineContext *context)
{
    (void)userContext; (void)context;
    return false;
}
bool ftcrashmc_getContextForThread(FTCrashThread thread, struct FTCrashMachineContext *context, bool isCrashedContext)
{
    (void)thread; (void)context; (void)isCrashedContext;
    return false;
}
void ftcrashsc_initSelfThread(FTCrashStackCursor *cursor, int skipEntries) { (void)cursor; (void)skipEntries; }
void ftcrashsc_initWithBacktrace(FTCrashStackCursor *cursor, const uintptr_t *backtrace, int backtraceLength, int skipEntries)
{
    (void)cursor; (void)backtrace; (void)backtraceLength; (void)skipEntries;
}
void ftcrashsc_initWithMachineContext(FTCrashStackCursor *cursor, int maxStackDepth, const struct FTCrashMachineContext *machineContext)
{
    (void)cursor; (void)maxStackDepth; (void)machineContext;
}
FTCrashThread ftcrashthread_self(void) { return 0; }

// 每个被调用的处理器追加一个字母：F = 本 SDK，P = 不转交的崩溃 SDK（如 Datadog 使用的 PLCrashReporter），
// p = 会转交给前一个处理器的崩溃 SDK。
static int g_out = -1;
static void emit(char c) { (void)write(g_out, &c, 1); }

static FTCrash_MonitorContext g_context;
static FTCrash_MonitorContext *notifyException(thread_t thread, FTCrash_ExceptionHandlingRequirements requirements)
{
    (void)thread;
    memset(&g_context, 0, sizeof(g_context));
    g_context.requirements = requirements;
    return &g_context;
}
static void handleException(FTCrash_MonitorContext *context) { (void)context; emit('F'); }

static NSUncaughtExceptionHandler *g_foreignPreviousException;
static struct sigaction g_foreignPreviousSignal;
static bool g_foreignForwards;

static void foreignException(NSException *exception)
{
    emit(g_foreignForwards ? 'p' : 'P');
    if (g_foreignForwards && g_foreignPreviousException != NULL) {
        g_foreignPreviousException(exception);
    }
}
static void foreignSignal(int sigNum, siginfo_t *info, void *context)
{
    emit(g_foreignForwards ? 'p' : 'P');
    if (g_foreignForwards && (g_foreignPreviousSignal.sa_flags & SA_SIGINFO)) {
        g_foreignPreviousSignal.sa_sigaction(sigNum, info, context);
        return;
    }
    signal(sigNum, SIG_DFL);
    raise(sigNum);
}
static void installForeignReporter(bool forwards)
{
    g_foreignForwards = forwards;
    g_foreignPreviousException = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&foreignException);
    struct sigaction action = { 0 };
    action.sa_sigaction = &foreignSignal;
    action.sa_flags = SA_SIGINFO;
    sigemptyset(&action.sa_mask);
    sigaction(SIGSEGV, &action, &g_foreignPreviousSignal);
}

typedef enum { ForeignNone, ForeignNonForwarding, ForeignForwarding } Foreign;
typedef enum { CrashException, CrashSignal } Crash;

static void runChild(Foreign foreign, int reinstallCount, Crash crash)
{
    alarm(5);  // 转交死循环会一直卡住，用 SIGALRM 让它变成测试失败。
    static FTCrash_ExceptionHandlerCallbacks callbacks = { .notify = notifyException, .handle = handleException };
    FTCrashMonitorAPI *exceptionAPI = ftcrashcm_nsexception_getAPI();
    FTCrashMonitorAPI *signalAPI = ftcrashcm_signal_getAPI();
    exceptionAPI->init(&callbacks);
    signalAPI->init(&callbacks);
    exceptionAPI->setEnabled(true);
    signalAPI->setEnabled(true);

    if (foreign != ForeignNone) {
        installForeignReporter(foreign == ForeignForwarding);
    }
    for (int i = 0; i < reinstallCount; i++) {
        exceptionAPI->reinstallHandlers();
        signalAPI->reinstallHandlers();
    }

    if (crash == CrashException) {
        @autoreleasepool {
            NSException *exception = [NSException exceptionWithName:@"Test" reason:@"reinstall" userInfo:nil];
            NSGetUncaughtExceptionHandler()(exception);
        }
        _exit(0);
    }
    raise(SIGSEGV);
    _exit(0);
}

static void expect(const char *name, Foreign foreign, int reinstallCount, Crash crash, const char *expectedOrder)
{
    int fds[2];
    assert(pipe(fds) == 0);
    pid_t pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        close(fds[0]);
        g_out = fds[1];
        runChild(foreign, reinstallCount, crash);
    }
    close(fds[1]);
    char order[16] = { 0 };
    ssize_t total = 0, n;
    while ((n = read(fds[0], order + total, sizeof(order) - 1 - (size_t)total)) > 0) total += n;
    close(fds[0]);
    int status = 0;
    assert(waitpid(pid, &status, 0) == pid);

    bool terminatedNormally = WIFEXITED(status) || (WIFSIGNALED(status) && WTERMSIG(status) != SIGALRM);
    if (strcmp(order, expectedOrder) != 0 || !terminatedNormally) {
        fprintf(stderr, "%s: handlers ran \"%s\", expected \"%s\"; %s\n", name, order, expectedOrder,
                terminatedNormally ? "terminated" : "hung (killed by SIGALRM)");
        exit(1);
    }
}

int main(void)
{
    const Crash crashes[] = { CrashException, CrashSignal };
    for (int i = 0; i < 2; i++) {
        Crash crash = crashes[i];
        // 后装且不转交：不重新挂载时，本 SDK 收不到崩溃。
        expect("non-forwarding reporter, no reinstall", ForeignNonForwarding, 0, crash, "P");
        expect("non-forwarding reporter, reinstall", ForeignNonForwarding, 1, crash, "FP");
        expect("non-forwarding reporter, reinstall twice", ForeignNonForwarding, 2, crash, "FP");
        // 重新挂载后对方会转交回来：两边各调用一次，且进程要能正常结束。
        expect("forwarding reporter, reinstall", ForeignForwarding, 1, crash, "Fp");
        // 没有被替换：重新挂载不能把本 SDK 串到自己身上。
        expect("no other reporter, reinstall", ForeignNone, 1, crash, "F");
    }
    printf("crash handler reinstall: all cases passed\n");
    return 0;
}
