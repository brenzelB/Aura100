"""Signing guards must reject a development/wrong-team profile before CI signs."""
import copy
import datetime as dt
import importlib.util
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("ios_release", Path(__file__).parents[1] / "prepare-ios-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class SigningGuards(unittest.TestCase):
    def setUp(self):
        self.profile = {
            "ExpirationDate": dt.datetime(2099, 1, 1), "TeamIdentifier": [release.TEAM_ID],
            "UUID": "11111111-2222-3333-4444-555555555555", "Name": "Aura Quest App Store",
            "Entitlements": {"application-identifier": f"{release.TEAM_ID}.{release.BUNDLE_ID}",
                             "aps-environment": "production", "com.apple.developer.applesignin": ["Default"]},
        }

    def test_valid_distribution_profile(self):
        release.validate_profile(self.profile)

    def test_reject_wrong_team_bundle_expiry_or_development(self):
        cases = [{"TeamIdentifier": ["OTHERTEAM0"]}, {"ExpirationDate": dt.datetime(2000, 1, 1)},
                 {"ProvisionedDevices": ["device"]}, {"ProvisionsAllDevices": True}, {"Name": "bad\nname"}]
        for change in cases:
            with self.subTest(change=change):
                profile = copy.deepcopy(self.profile)
                profile.update(change)
                with self.assertRaises(ValueError):
                    release.validate_profile(profile)
        for key, value in [("application-identifier", release.TEAM_ID + ".wrong.app"),
                           ("aps-environment", "development"), ("com.apple.developer.applesignin", []),
                           ("get-task-allow", True)]:
            with self.subTest(key=key):
                profile = copy.deepcopy(self.profile)
                profile["Entitlements"][key] = value
                with self.assertRaises(ValueError):
                    release.validate_profile(profile)

    def test_firebase_project_and_tracking_guard(self):
        config = {"BUNDLE_ID": release.BUNDLE_ID, "PROJECT_ID": "auraquest-fa2a1", "GOOGLE_APP_ID": "1:123:ios:test"}
        release.validate_firebase(config)
        for key, value in [("BUNDLE_ID", "wrong.app"), ("PROJECT_ID", "wrong"),
                           ("IS_ANALYTICS_ENABLED", True), ("IS_ADS_ENABLED", True)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_firebase(dict(config, **{key: value}))

    def test_only_runner_settings_change_and_patch_is_idempotent(self):
        project = Path(__file__).parents[2] / "ios/Runner.xcodeproj/project.pbxproj"
        original = project.read_text(encoding="utf-8")
        patched = release.patch_project(original, self.profile["Name"])
        self.assertEqual(patched.count('PROVISIONING_PROFILE_SPECIFIER = "Aura Quest App Store";'), 3)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER = com.auraquest.auraQuest.RunnerTests;", patched)
        self.assertEqual(release.patch_project(patched, self.profile["Name"]), patched)

    def test_workflow_can_use_firebase_already_in_runner(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[2]) as directory:
            root = Path(directory)
            source = Path(__file__).parents[2] / "ios"
            (root / "ios/Runner.xcodeproj").mkdir(parents=True)
            (root / "ios/Runner").mkdir(parents=True)
            for relative in ("Runner.xcodeproj/project.pbxproj", "Runner/Runner.entitlements"):
                shutil.copyfile(source / relative, root / "ios" / relative)
            firebase = root / "ios/Runner/GoogleService-Info.plist"
            config = {"BUNDLE_ID": release.BUNDLE_ID, "PROJECT_ID": "auraquest-fa2a1",
                      "GOOGLE_APP_ID": "1:123:ios:test"}
            firebase.write_bytes(plistlib.dumps(config))
            profile = root / "profile.plist"
            profile.write_bytes(plistlib.dumps(self.profile))
            with patch.object(sys, "argv", ["prepare-ios-release.py", "--profile", str(profile),
                                            "--firebase", str(firebase), "--root", str(root)]), \
                    patch.dict(os.environ, {"GITHUB_ENV": str(root / "github-env")}):
                release.main()
            export = plistlib.loads((root / "build/apple-signing/ExportOptions.plist").read_bytes())
            self.assertEqual(export["teamID"], release.TEAM_ID)
            self.assertEqual(plistlib.loads(firebase.read_bytes()), config)
            self.assertEqual(plistlib.loads((root / "ios/Runner/Runner.entitlements").read_bytes())["aps-environment"], "production")


if __name__ == "__main__":
    unittest.main()
