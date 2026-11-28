#!/usr/bin/env python3
"""Run published Browser SDK 3.3.16 bundles inside an actual iOS WKWebView."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

PACKAGES = {
    'browser-rum': ('dataflux-rum.js', '74b5622442999da00facde44c66bd8a6aefd6a7ad4e5ed184feaa301f6571f62'),
    'browser-rum-slim': ('dataflux-rum-slim.js', '6b22e5978330b488df0eb80ef72b2a9249cbf4996148fc55833e4e778f33e1d4'),
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Booted iOS simulator UDID')
    parser.add_argument('--framework', type=Path, help='Existing current-branch iOS Simulator GuanceSDK.framework')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--ruby', default=os.environ.get('RUBY_EXECUTABLE', 'ruby'))
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    repo = source.parents[1]
    output = args.output or Path(tempfile.mkdtemp(prefix='webvisitor-integration-'))
    output.mkdir(parents=True, exist_ok=True)
    print('Output:', output, flush=True)
    for name in ['main.m', 'page.html', 'server.py', 'create_project.rb']:
        shutil.copyfile(source / name, output / name)
    for package, (bundle, expected_hash) in PACKAGES.items():
        url = f'https://registry.npmjs.org/@cloudcare/{package}/-/{package}-3.3.16.tgz'
        archive = output / (package + '.tgz')
        data = archive.read_bytes() if archive.exists() else urllib.request.urlopen(url, timeout=60).read()
        if hashlib.sha256(data).hexdigest() != expected_hash:
            raise RuntimeError(f'Published asset hash mismatch: {package}')
        archive = output / (package + '.tgz')
        archive.write_bytes(data)
        with tarfile.open(archive) as tar:
            for relative in ['package/package.json', 'package/bundle/' + bundle]:
                destination = output / package / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(tar.extractfile(relative).read())
    (output / 'Support.swift').write_text('import Foundation\n')
    info = {
        'CFBundleExecutable': '$(EXECUTABLE_NAME)',
        'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
        'CFBundleName': 'WebVisitorIntegration', 'CFBundlePackageType': 'APPL',
        'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0',
        'NSAppTransportSecurity': {'NSAllowsArbitraryLoads': True, 'NSAllowsLocalNetworking': True},
        'UILaunchScreen': {},
        'UIApplicationSceneManifest': {
            'UIApplicationSupportsMultipleScenes': False,
            'UISceneConfigurations': {'UIWindowSceneSessionRoleApplication': [{
                'UISceneConfigurationName': 'Default', 'UISceneDelegateClassName': 'SceneDelegate'}]},
        },
    }
    (output / 'Info.plist').write_bytes(plistlib.dumps(info))
    def build(command, filename):
        with (output / filename).open('w') as log:
            subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, check=True)
    framework = args.framework
    if framework is None:
        build(['xcodebuild', 'build', '-quiet', '-project', 'FTSDK.xcodeproj', '-scheme', 'FTSDK',
               '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', str(output / 'sdk-build'),
               'CODE_SIGNING_ALLOWED=NO'], 'sdk-build.log')
        framework = output / 'sdk-build/Build/Products/Debug-iphonesimulator/GuanceSDK.framework'
    env = dict(os.environ, WEBVISITOR_TEST_ROOT=str(output), WEBVISITOR_FRAMEWORK=str(framework.resolve()))
    subprocess.run([args.ruby, str(output / 'create_project.rb')], env=env, check=True)
    build(['xcodebuild', 'build', '-quiet', '-project', str(output / 'Integration.xcodeproj'),
           '-scheme', 'WebVisitorIntegration', '-destination', 'generic/platform=iOS Simulator',
           '-derivedDataPath', str(output / 'build'), 'CODE_SIGNING_ALLOWED=NO'], 'app-build.log')
    server_log = (output / 'server.log').open('w')
    server = subprocess.Popen([sys.executable, str(output / 'server.py')], stdout=server_log, stderr=subprocess.STDOUT)
    bundle_id = 'com.guance.webvisitor.integration'
    try:
        app = output / 'build/Build/Products/Debug-iphonesimulator/WebVisitorIntegration.app'
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, bundle_id], capture_output=True)
        subprocess.run(['xcrun', 'simctl', 'install', args.device, str(app)], check=True)
        container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.device, bundle_id, 'data'], text=True).strip())
        result_path = container / 'Documents/results.json'
        old_result = result_path.read_bytes() if result_path.exists() else None
        subprocess.run(['xcrun', 'simctl', 'launch', args.device, bundle_id], check=True)
        deadline, seen = time.monotonic() + args.timeout, 0
        while time.monotonic() < deadline:
            if server.poll() is not None:
                raise RuntimeError('Local HTTP server exited; see server.log (port 18763 must be free)')
            try:
                data = result_path.read_bytes()
                report = json.loads(data) if data != old_result else None
            except (OSError, ValueError):
                report = None
            if report:
                for case in report['results'][seen:]:
                    print(case['bundle'], case['scenario'], 'FAIL' if case['failures'] else 'PASS', flush=True)
                seen = len(report['results'])
                if report['completed']:
                    (output / 'results.json').write_bytes(data)
                    failures = sum(len(case['failures']) for case in report['results'])
                    print(f"Completed {seen} cases, {failures} failures; {output / 'results.json'}")
                    return 1 if failures or seen != 16 else 0
            time.sleep(0.25)
        raise TimeoutError('Integration run timed out; inspect the simulator and partial results at ' + str(result_path))
    finally:
        subprocess.run(['xcrun', 'simctl', 'terminate', args.device, bundle_id], capture_output=True)
        server.terminate()
        server.wait(timeout=5)
        server_log.close()

if __name__ == '__main__':
    sys.exit(main())
