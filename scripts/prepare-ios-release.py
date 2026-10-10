"""Validate Apple's profile and configure only the CI checkout for signing.

No private key or password is read or logged here. The workflow imports the
certificate into an ephemeral macOS keychain and passes a decoded profile.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import re
import shutil

BUNDLE_ID = "com.auraquest.auraQuest"
TEAM_ID = "W558BUSST2"


def validate_profile(profile, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime):
        raise ValueError("Profile has no expiration date")
    if expiry.replace(tzinfo=dt.timezone.utc) <= now:
        raise ValueError("Provisioning profile expired")
    if profile.get("TeamIdentifier") != [TEAM_ID]:
        raise ValueError("Profile belongs to a different Apple team")
    entitlements = profile.get("Entitlements", {})
    if entitlements.get("application-identifier") != f"{TEAM_ID}.{BUNDLE_ID}":
        raise ValueError("Profile is not for the exact Aura Quest bundle ID")
    if entitlements.get("get-task-allow", False) or profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        raise ValueError("An App Store distribution profile is required")
    if entitlements.get("aps-environment") != "production":
        raise ValueError("Profile must include production Push Notifications")
    if "Default" not in entitlements.get("com.apple.developer.applesignin", []):
        raise ValueError("Profile must include Sign in with Apple")
    for key in ("UUID", "Name"):
        if not isinstance(profile.get(key), str) or not profile[key] or any(c in profile[key] for c in "\r\n\0"):
            raise ValueError("Invalid profile " + key)
    if not re.fullmatch(r"[A-Fa-f0-9-]{36}", profile["UUID"]):
        raise ValueError("Invalid provisioning profile UUID")


def validate_firebase(config):
    if config.get("BUNDLE_ID") != BUNDLE_ID:
        raise ValueError("Firebase configuration belongs to another app")
    if config.get("PROJECT_ID") != "auraquest-fa2a1" or ":ios:" not in config.get("GOOGLE_APP_ID", ""):
        raise ValueError("Wrong Firebase project or platform")
    if config.get("IS_ANALYTICS_ENABLED") or config.get("IS_ADS_ENABLED"):
        raise ValueError("Unexpected Firebase analytics/ads configuration")


def validate_app_info(info, build_number=None):
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise ValueError("Exported IPA belongs to another app")
    if build_number is not None and info.get("CFBundleVersion") != str(build_number):
        raise ValueError("Exported IPA has the wrong build number")
    if 2 in info.get("UIDeviceFamily", []) and not info.get("UIRequiresFullScreen", False):
        required = {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
        orientations = set(info.get("UISupportedInterfaceOrientations", []))
        ipad_orientations = set(info.get("UISupportedInterfaceOrientations~ipad", orientations))
        if not required.issubset(orientations) or not required.issubset(ipad_orientations):
            raise ValueError("iPad multitasking requires all four interface orientations")


def patch_project(source, profile_name):
    count = 0

    def replace(match):
        nonlocal count
        block = match.group(0)
        if f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};" not in block:
            return block
        count += 1
        keys = ["CODE_SIGN_STYLE", "CODE_SIGN_IDENTITY", '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"',
                "DEVELOPMENT_TEAM", "PROVISIONING_PROFILE_SPECIFIER"]
        for key in keys:
            block = re.sub(r"^[ \t]*" + re.escape(key) + r"[ \t]*=.*?;\n", "", block, flags=re.M)
        settings = {
            "CODE_SIGN_STYLE": "Manual", "CODE_SIGN_IDENTITY": "Apple Distribution",
            '"CODE_SIGN_IDENTITY[sdk=iphoneos*]"': "Apple Distribution",
            "DEVELOPMENT_TEAM": TEAM_ID, "PROVISIONING_PROFILE_SPECIFIER": profile_name,
        }
        added = "".join(f"\t\t\t\t{key} = {json.dumps(value)};\n" for key, value in settings.items())
        return block.replace("buildSettings = {\n", "buildSettings = {\n" + added, 1)

    result = re.sub(r"buildSettings = \{\n.*?\n\t\t\t\};", replace, source, flags=re.S)
    if count != 3:
        raise ValueError(f"Expected exactly three Runner configurations, found {count}")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--firebase", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    profile = plistlib.loads(args.profile.read_bytes())
    config = plistlib.loads(args.firebase.read_bytes())
    validate_profile(profile)
    validate_firebase(config)
    project = args.root / "ios/Runner.xcodeproj/project.pbxproj"
    source = patch_project(project.read_text(encoding="utf-8"), profile["Name"])
    output = args.root / "build/apple-signing"
    output.mkdir(parents=True, exist_ok=True)
    export = {
        "method": "app-store-connect", "destination": "export", "teamID": TEAM_ID,
        "signingStyle": "manual", "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {BUNDLE_ID: profile["Name"]},
        "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
    }
    (output / "ExportOptions.plist").write_bytes(plistlib.dumps(export))
    entitlements_path = args.root / "ios/Runner/Runner.entitlements"
    entitlements = plistlib.loads(entitlements_path.read_bytes())
    entitlements["aps-environment"] = "production"
    project.write_text(source, encoding="utf-8")
    entitlements_path.write_bytes(plistlib.dumps(entitlements))
    destination = args.root / "ios/Runner/GoogleService-Info.plist"
    if args.firebase.resolve() != destination.resolve():
        shutil.copyfile(args.firebase, destination)
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
            stream.write(f'IOS_PROFILE_UUID={profile["UUID"]}\n')
    print("Validated App Store profile and Firebase; prepared Runner signing and export options.")


if __name__ == "__main__":
    main()
