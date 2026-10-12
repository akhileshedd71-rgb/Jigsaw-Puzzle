#!/usr/bin/env python3
"""Install verified Linux SDK packages for Godot APK or Gradle/AAB export.

This does not install Gradle, the Android NDK, an emulator, or release credentials.
Archive checksums are verified against Google's official SDK repository metadata.
"""

from argparse import ArgumentParser
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
from tempfile import TemporaryDirectory
from urllib.request import urlopen
from xml.etree import ElementTree
from zipfile import ZipFile


BASE_URL = "https://dl.google.com/android/repository/"
BUILD_TOOLS = "36.0.0"


def install_package(repository, package, destination, required_files):
    if all((destination / name).is_file() for name in required_files):
        print(f"Reusing {package} at {destination}")
        return
    entry = next(node for node in repository.findall("remotePackage") if node.attrib["path"] == package)
    archive = next(node for node in entry.findall("./archives/archive") if node.findtext("host-os") in (None, "linux"))
    complete = archive.find("complete")
    url = complete.findtext("url")
    checksum_entry = complete.find("checksum")
    digest = hashlib.new(checksum_entry.attrib["type"])
    with TemporaryDirectory(prefix="piecepop-android-") as temporary:
        path = Path(temporary) / "package.zip"
        print(f"Downloading {package}...", flush=True)
        with urlopen(BASE_URL + url, timeout=120) as response, path.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != checksum_entry.text.strip():
            raise RuntimeError(f"Official checksum verification failed for {package}")
        if path.stat().st_size != int(complete.findtext("size")):
            raise RuntimeError(f"Official archive size verification failed for {package}")
        with ZipFile(path) as archive:
            for member in archive.infolist():
                parts = Path(member.filename).parts[1:]
                if not parts:
                    continue
                if ".." in parts or Path(member.filename).is_absolute():
                    raise RuntimeError("Unsafe path in the archive")
                target = destination.joinpath(*parts)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
                permissions = (member.external_attr >> 16) & 0o777
                if permissions:
                    target.chmod(permissions)
        print(f"Verified and installed {package} at {destination}")


def configure_editor(sdk_root, java_home):
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    settings = config_root / "godot" / "editor_settings-4.6.tres"
    settings.parent.mkdir(parents=True, exist_ok=True)
    content = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    if "[resource]" not in content:
        raise RuntimeError(f"Unrecognized editor settings format at {settings}")
    for key, value in (("export/android/java_sdk_path", java_home), ("export/android/android_sdk_path", sdk_root)):
        escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
        line = f'{key} = "{escaped}"'
        pattern = rf"^{re.escape(key)}\s*=.*$"
        if re.search(pattern, content, flags=re.MULTILINE):
            content = re.sub(pattern, lambda _: line, content, flags=re.MULTILINE)
        else:
            content = content.replace("[resource]", "[resource]\n" + line, 1)
    settings.write_text(content)
    print(f"Configured Godot's Android and Java paths in {settings}")


def main():
    parser = ArgumentParser(description=__doc__)
    default_sdk = Path(os.environ.get("ANDROID_SDK_ROOT", Path.home() / "Android" / "Sdk"))
    parser.add_argument("--sdk-root", type=Path, default=default_sdk)
    parser.add_argument("--configure-godot", action="store_true", help="Set only the Android SDK and Java paths in Godot 4.6 editor settings")
    parser.add_argument("--gradle", action="store_true", help="Also install SDK 36, Build-Tools 36.1.0, and sdkmanager for AAB export")
    parser.add_argument("--java-home", type=Path, default=None)
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
        parser.error("This helper installs Linux x86_64 packages. Use Android Studio on other hosts.")
    sdk_root = args.sdk_root.resolve()
    java_home = args.java_home
    if java_home is None and shutil.which("java"):
        java_home = Path(shutil.which("java")).resolve().parents[1]
    if args.configure_godot and (java_home is None or not (java_home / "bin" / "keytool").is_file()):
        parser.error("Install Java 17 or later with keytool, or supply --java-home.")
    with urlopen(BASE_URL + "repository2-3.xml", timeout=60) as response:
        repository = ElementTree.fromstring(response.read())
    install_package(repository, "platform-tools", sdk_root / "platform-tools", ("adb", "source.properties"))
    install_package(repository, f"build-tools;{BUILD_TOOLS}", sdk_root / "build-tools" / BUILD_TOOLS, ("apksigner", "lib/apksigner.jar", "aapt", "source.properties"))
    if args.gradle:
        install_package(repository, "cmdline-tools;latest", sdk_root / "cmdline-tools" / "latest", ("bin/sdkmanager", "source.properties"))
        install_package(repository, "platforms;android-36", sdk_root / "platforms" / "android-36", ("android.jar", "source.properties"))
        install_package(repository, "build-tools;36.1.0", sdk_root / "build-tools" / "36.1.0", ("apksigner", "aapt2", "source.properties"))
    if args.configure_godot:
        configure_editor(sdk_root, java_home.resolve())
    print("Android SDK packages are ready. Install the matching Godot export templates too.")
    if args.gradle:
        print("AAB builds also require a full JDK with javac and the Godot Android build template.")


if __name__ == "__main__":
    main()
