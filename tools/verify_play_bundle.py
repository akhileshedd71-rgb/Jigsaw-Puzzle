#!/usr/bin/env python3
"""Validate the signed Play bundle, manifest, offline assets, and 16 KB ELF alignment."""

from argparse import ArgumentParser
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
from xml.etree import ElementTree
from zipfile import ZipFile


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--bundletool", type=Path, required=True)
    parser.add_argument("--java-home", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=Path("builds/android/validation-report.json"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    java = str(args.java_home / "bin/java")

    def bundletool(*command):
        return subprocess.check_output([java, "-jar", str(args.bundletool), *command, "--bundle=" + str(args.bundle)], text=True)

    bundletool("validate")
    manifest = ElementTree.fromstring(bundletool("dump", "manifest", "--module=base"))
    config = json.loads(bundletool("dump", "config"))
    ns = "{http://schemas.android.com/apk/res/android}"
    application = manifest.find("application")
    sdk = manifest.find("uses-sdk")
    package = manifest.get("package")
    assert package == "com.akhileshedd.piecepop", "Wrong application ID"
    assert application.get(ns + "debuggable", "false") == "false", "Debug builds cannot be published"
    assert application.get(ns + "allowBackup") == "false", "Backup behavior disagrees with the privacy policy"
    assert sdk.get(ns + "targetSdkVersion") == "36"
    assert sdk.get(ns + "minSdkVersion") == "24"
    permissions = sorted(p.get(ns + "name") for p in manifest.findall("uses-permission"))
    assert permissions == ["android.permission.VIBRATE"], "Review unexpected merged permissions"
    assert config["optimizations"]["uncompressNativeLibraries"]["alignment"] == "PAGE_ALIGNMENT_16K"
    signature = subprocess.check_output([str(args.java_home / "bin/jarsigner"), "-verify", str(args.bundle)], text=True)
    assert "jar verified." in signature, "A valid JAR signature is required"
    certificate = subprocess.check_output([str(args.java_home / "bin/keytool"), "-printcert", "-jarfile", str(args.bundle)], text=True)
    assert "Android Debug" not in certificate and "CN=Godot," not in certificate, "A debug signing certificate cannot be used"
    fingerprint = re.search(r"SHA256:\s*([A-Fa-f0-9:]+)", certificate).group(1)
    assets = re.findall(r'"asset":\s*"res://assets/puzzles/([^\"]+)"', (root / "scripts/game_state.gd").read_text())
    native = []
    with ZipFile(args.bundle) as archive:
        names = archive.namelist()
        for name in names:
            assert not name.endswith((".p12", ".jks", ".keystore")) and "keystore-password" not in name
        for asset in assets:
            assert any(asset + "-" in name and name.endswith(".ctex") for name in names), asset
        policies = [name for name in names if name.endswith("assets/legal/privacy-policy.txt")]
        assert len(policies) == 1
        assert archive.read(policies[0]) == (root / "assets/legal/privacy-policy.txt").read_bytes()
        for name in names:
            if not name.endswith(".so"):
                continue
            assert "/arm64-v8a/" in name, "Unexpected architecture"
            binary = archive.read(name)
            assert binary[:6] == b"\x7fELF\x02\x01", "Expected little-endian ELF64"
            start = struct.unpack_from("<Q", binary, 32)[0]
            size, count = struct.unpack_from("<HH", binary, 54)
            alignments = []
            for index in range(count):
                offset = start + index * size
                if struct.unpack_from("<I", binary, offset)[0] != 1:
                    continue
                file_offset, virtual_address = struct.unpack_from("<QQ", binary, offset + 8)
                alignment = struct.unpack_from("<Q", binary, offset + 48)[0]
                assert alignment >= 16384 and (virtual_address - file_offset) % 16384 == 0, name
                alignments.append(alignment)
            assert alignments
            native.append({"file": name, "load_segment_alignments": alignments})
        assert native
    with args.bundle.open("rb") as stream:
        checksum = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {
        "bundle": args.bundle.name, "sha256": checksum, "bytes": args.bundle.stat().st_size,
        "package": package, "version_name": manifest.get(ns + "versionName"),
        "version_code": int(manifest.get(ns + "versionCode")), "min_sdk": 24, "target_sdk": 36,
        "debuggable": False, "allow_backup": False, "permissions": permissions,
        "upload_certificate_sha256": fingerprint, "bundletool_validation": "passed",
        "signature_verification": "passed", "bundled_catalog_images": len(assets),
        "privacy_policy_matches_source": True, "bundle_page_alignment": "16 KB", "native_libraries": native,
        "native_device_execution": "not tested", "google_play_review": "not submitted",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
