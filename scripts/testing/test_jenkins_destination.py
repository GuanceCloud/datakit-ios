"""Exercise the Jenkins script's real destination selection without pod/test side effects.

Run: python3 scripts/testing/test_jenkins_destination.py
"""

import os
from pathlib import Path
import subprocess
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "JenkinsTestingBash.sh"
DESTINATIONS = """
Destinations compatible with the "FTMobileSDKUnitTestsForCmd" scheme:
    { platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:mac-id, name:My Mac }
    { platform:iOS, id:phone-id, name:Test Phone }
    { platform:iOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder, name:Any iOS Simulator Device }
    { platform:iOS Simulator, arch:arm64, id:ipad-id, OS:27.0, name:iPad (A16) }
    { platform:iOS Simulator, arch:arm64, id:iphone-id, OS:27.0, name:iPhone 18 Pro }
    { platform:tvOS Simulator, arch:arm64, id:tv-id, OS:27.0, name:Apple TV 4K }
Destinations incompatible with the "FTMobileSDKUnitTestsForCmd" scheme:
    { platform:iOS Simulator, arch:arm64, id:bad-id, OS:27.0, name:iPhone 18, error:Unavailable }
"""


class DestinationTests(unittest.TestCase):
    def resolve(self, requested="", destinations=DESTINATIONS, query_status=0, platform="iOS Simulator"):
        script = SCRIPT.read_text()
        # Load the actual function and iOS call site, avoiding scheme edits,
        # CocoaPods installation and the test runs surrounding this section.
        selection = script[script.index("function findSimulator(){"):script.index("## Test iOS")]
        harness = """
set -eo pipefail
xcodebuild() {
    [[ "$*" == '-workspace FTSDK.xcworkspace -scheme FTMobileSDKUnitTestsForCmd -showdestinations' ]] || return 99
    printf '%s\\n' "$DESTINATION_FIXTURE"
    return "$QUERY_STATUS"
}
""" + selection + '\nprintf "%s\\n" "$IOS_DESTINATION"\n'
        if platform != "iOS Simulator":
            harness = harness.replace('"FTMobileSDKUnitTestsForCmd" "iOS Simulator"',
                                      f'"FTMobileSDKUnitTestsForCmd" "{platform}"')
        return subprocess.run(
            ["/bin/bash", "-c", harness], text=True, capture_output=True,
            env={**os.environ, "DEVICE_DESTINATION": requested,
                 "DESTINATION_FIXTURE": destinations, "QUERY_STATUS": str(query_status)},
        )

    def test_missing_requested_device_falls_back(self):
        result = self.resolve("platform=iOS Simulator,OS=27.0,name=iPhone 18")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=ipad-id")
        self.assertIn("Warning:", result.stderr)

    def test_valid_name_and_os_are_preserved(self):
        requested = "platform=iOS Simulator,OS=27.0,name=iPhone 18 Pro"
        result = self.resolve(requested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), requested)
        self.assertNotIn("Warning:", result.stderr)

    def test_wrong_os_falls_back(self):
        result = self.resolve("platform=iOS Simulator,OS=26.0,name=iPhone 18 Pro")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=ipad-id")

    def test_valid_id_is_preserved(self):
        requested = "platform=iOS Simulator,id=iphone-id"
        result = self.resolve(requested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), requested)

    def test_stale_id_falls_back(self):
        result = self.resolve("platform=iOS Simulator,id=deleted-id")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=ipad-id")

    def test_latest_os_is_preserved(self):
        requested = "platform=iOS Simulator,OS=latest,name=iPhone 18 Pro"
        result = self.resolve(requested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), requested)

    def test_default_skips_placeholders_and_other_platforms(self):
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=iOS Simulator,id=ipad-id")

    def test_physical_device_is_preserved(self):
        requested = "platform=iOS,id=phone-id"
        result = self.resolve(requested)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), requested)

    def test_no_available_simulator_fails_with_diagnostics(self):
        destinations = """
    { platform:iOS Simulator, id:placeholder, name:Any iOS Simulator Device }
    { platform:tvOS Simulator, id:tv-id, OS:27.0, name:Apple TV }
    { platform:iOS Simulator, id:bad-id, OS:27.0, name:iPhone, error:Unavailable }
"""
        result = self.resolve("platform=iOS Simulator,name=iPhone 18", destinations)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("No available iOS Simulator", result.stderr)

    def test_query_failure_is_not_reported_as_a_device(self):
        result = self.resolve(query_status=65)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_tvos_uses_tvos_simulator(self):
        result = self.resolve(platform="tvOS Simulator")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "platform=tvOS Simulator,id=tv-id")


if __name__ == "__main__":
    unittest.main()
