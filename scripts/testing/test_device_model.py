#!/usr/bin/env python3
"""Check production model-selection/decoding methods with deterministic system inputs.

Runs a small macOS Foundation harness, compiling the iOS mapping branch.
Use --source to verify a saved pre-fix FTPresetProperty.m fails this regression.
This does not emulate NSProcessInfo or establish physical iOS-on-Mac behavior.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path,
                    default=root / 'Sources/Core/BaseUtils/Base/FTPresetProperty.m')
args = parser.parse_args()
source = args.source.read_text()


def method(name):
    start = source.rindex('+ (' + name)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


methods = method('NSString *)deviceInfo')
for name in ['NSString *)unameMachineIdentifier', 'NSString *)modelIdentifier']:
    if '+ (' + name in source:
        methods += '\n' + method(name)
header = '''#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#include <assert.h>
#include <string.h>
#undef TARGET_OS_IOS
#define TARGET_OS_IOS 1
#undef TARGET_OS_TV
#define TARGET_OS_TV 0
static int sysctlMode;
static int fakeUname(struct utsname *info) {
    memset(info, 0, sizeof(*info)); strcpy(info->machine, "iPad13,4"); return 0;
}
static int fakeSysctl(const char *key, void *out, size_t *length, void *newValue, size_t newLength) {
    assert(strcmp(key, "hw.model") == 0);
    if (sysctlMode == 1 && !out) return -1;
    if (sysctlMode == 2 && !out) { *length = 0; return 0; }
    if (sysctlMode == 3 && out) return -1;
    if (!out) { *length = 8; return 0; }
    if (sysctlMode == 4) { *length = 0; return 0; }
    if (sysctlMode == 5) { memset(out, 0, *length); return 0; }
    if (sysctlMode == 6) { memset(out, 255, *length); return 0; }
    memcpy(out, "Mac14,2", 8);
    if (sysctlMode == 7) *length = 7;
    return 0;
}
#define uname fakeUname
#define sysctlbyname fakeSysctl
@interface FTPresetProperty : NSObject
+ (BOOL)isiOSAppOnMac;
+ (NSString *)deviceInfo;
+ (NSString *)modelIdentifier;
+ (NSString *)unameMachineIdentifier;
@end
@implementation FTPresetProperty
+ (BOOL)isiOSAppOnMac { return NO; }
'''
footer = '''
@end
@interface IPad : FTPresetProperty @end
@implementation IPad
+ (NSString *)unameMachineIdentifier { return @"iPad13,4"; }
@end
@interface Mac : IPad @end
@implementation Mac
+ (BOOL)isiOSAppOnMac { return YES; }
@end
int main(void) { @autoreleasepool {
    NSString *actual = [Mac deviceInfo];
    if (![actual isEqual:@"Mac14,2"]) { NSLog(@"FAIL: expected Mac14,2, got %@", actual); return 1; }
    if (![[IPad deviceInfo] isEqual:@"iPad Pro 3 (11-inch) "]) { NSLog(@"FAIL: iPad mapping"); return 1; }
    for (int mode = 1; mode <= 7; mode++) {
        sysctlMode = mode;
        NSString *expected = mode == 7 ? @"Mac14,2" : @"Unknown Mac";
        NSString *value = [Mac deviceInfo];
        if (![value isEqual:expected]) { NSLog(@"FAIL mode %d: expected %@, got %@", mode, expected, value); return 1; }
    }
    NSLog(@"PASS: Mac/iPad selection, sysctl size/read failures, zero length, empty/invalid UTF-8, bounded decoding");
} return 0; }
'''
with tempfile.TemporaryDirectory(prefix='ft-device-model-') as directory:
    harness = Path(directory) / 'check.m'
    executable = Path(directory) / 'check'
    harness.write_text(header + methods + footer)
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-framework', 'Foundation',
                    str(harness), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
