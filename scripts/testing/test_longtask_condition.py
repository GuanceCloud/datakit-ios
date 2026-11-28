#!/usr/bin/env python3
"""Exercise the actual LongTask detector with controlled clocks and condition waits.

Run on macOS, or use --simulator UDID for an already booted iOS simulator.
--source accepts the pre-change detector with the same private wait seam.
"""
import argparse
from pathlib import Path
import platform
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT / 'Sources/Core/FTRUM/LongTask/FTLongTaskDetector.m')
parser.add_argument('--output', type=Path)
parser.add_argument('--simulator')
args = parser.parse_args()
output = args.output or Path(tempfile.mkdtemp(prefix='ft-longtask-condition-'))
output.mkdir(parents=True, exist_ok=True)
sdk = 'iphonesimulator' if args.simulator else 'macosx'
sdk_path = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
target = f'{platform.machine()}-apple-' + ('ios15.0-simulator' if args.simulator else 'macos12.0')
common = ['xcrun', 'clang', '-target', target, '-isysroot', sdk_path,
          '-fobjc-arc', '-fblocks', '-Wno-incomplete-implementation', '-Wno-nullability-completeness']
for directory in sorted({p.parent for p in (ROOT / 'Sources').rglob('*.h')}):
    common += ['-I', str(directory)]
detector_object = output / 'detector.o'
subprocess.run(common + ['-Dpthread_cond_timedwait_relative_np=FTTestConditionWait',
                        '-Dpthread_cond_wait=FTTestUnexpectedUntimedWait',
                        '-c', str(args.source), '-o', str(detector_object)], check=True)
executable = output / 'LongTaskConditionCheck'
subprocess.run(common + [str(ROOT / 'scripts/testing/longtask-condition-check.m'),
                        str(detector_object), '-framework', 'Foundation', '-framework', 'CoreFoundation',
                        '-framework', 'UIKit' if args.simulator else 'AppKit',
                        '-o', str(executable)], check=True)
if args.simulator:
    subprocess.run(['codesign', '--force', '--sign', '-', str(executable)], check=True, capture_output=True)
    command = ['xcrun', 'simctl', 'spawn', args.simulator, str(executable)]
else:
    command = [str(executable)]
# The native startup case installs a process-wide platform hook; isolate it
# from the scripted suite's fake-class hook compatibility checks.
combined_output = ''
for arguments in [['--real-runloop-startup'], []]:
    result = subprocess.run(command + arguments, capture_output=True, text=True, timeout=30)
    combined_output += result.stdout + result.stderr
    (output / 'result.txt').write_text(combined_output)
    print(result.stdout, end='')
    print(result.stderr, end='')
    if result.returncode:
        raise SystemExit(result.returncode)
