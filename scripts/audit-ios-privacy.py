"""Inspect the exported IPA; never print Firebase keys or private signing data."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("ipa", type=Path)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
with zipfile.ZipFile(args.ipa) as ipa:
    names = ipa.namelist()
    roots = [p for p in names if p.startswith("Payload/") and p.count("/") == 2 and p.endswith(".app/Info.plist")]
    if len(roots) != 1:
        raise SystemExit("Expected exactly one exported application")
    root = roots[0].removesuffix("Info.plist")
    info = plistlib.loads(ipa.read(root + "Info.plist"))
    firebase = plistlib.loads(ipa.read(root + "GoogleService-Info.plist"))
    if firebase.get("BUNDLE_ID") != "com.auraquest.auraQuest" or firebase.get("IS_ANALYTICS_ENABLED") or firebase.get("IS_ADS_ENABLED"):
        raise SystemExit("Unexpected Firebase configuration")
    manifests = []
    for path in names:
        if path.endswith("PrivacyInfo.xcprivacy"):
            manifests.append({"path": path.removeprefix(root), **plistlib.loads(ipa.read(path))})
    frameworks = sorted(set(p.split("/Frameworks/")[1].split("/")[0] for p in names if "/Frameworks/" in p and p.split("/Frameworks/")[1]))
    if "webcrypto.framework" in frameworks:
        raise SystemExit("Unused webcrypto framework is still present")
    app_binary = ipa.read(root + "Frameworks/App.framework/App")
    if b"store-preview.invalid" in app_binary:
        raise SystemExit("Store-only fixture entrypoint unexpectedly present in release")
    flutter_binary = ipa.read(root + "Frameworks/Flutter.framework/Flutter")
    report = {
        "ipaSha256": hashlib.sha256(args.ipa.read_bytes()).hexdigest(),
        "bundleId": info.get("CFBundleIdentifier"),
        "version": info.get("CFBundleShortVersionString"),
        "build": info.get("CFBundleVersion"),
        "minimumOS": info.get("MinimumOSVersion"),
        "sdk": info.get("DTSDKName"),
        "usesNonExemptEncryption": info.get("ITSAppUsesNonExemptEncryption", "not declared"),
        "frameworks": frameworks,
        "firebaseAnalytics": bool(firebase.get("IS_ANALYTICS_ENABLED")),
        "firebaseAds": bool(firebase.get("IS_ADS_ENABLED")),
        "storeFixturesInRelease": False,
        "flutterContainsBoringSslMarker": b"BoringSSL" in flutter_binary,
        "privacyManifests": manifests,
    }
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2), encoding="utf8")
    summary = {key: value for key, value in report.items() if key != "privacyManifests"}
    summary["privacyManifestCount"] = len(manifests)
    summary["collectedTypes"] = sorted(set(d["NSPrivacyCollectedDataType"] for m in manifests for d in m.get("NSPrivacyCollectedDataTypes", [])))
    summary["trackingDeclared"] = any(m.get("NSPrivacyTracking") or any(d.get("NSPrivacyCollectedDataTypeTracking") for d in m.get("NSPrivacyCollectedDataTypes", [])) for m in manifests)
    print(json.dumps(summary, indent=2))
