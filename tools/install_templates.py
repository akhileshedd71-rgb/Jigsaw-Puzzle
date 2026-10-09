#!/usr/bin/env python3
"""Install official Godot 4.6.3 Web, Android, and Linux x86_64 export templates.

Downloads the full upstream archive and verifies its official SHA-512 checksum
before extracting anything. The approximately 1.2 GB archive is discarded.
"""

from argparse import ArgumentParser
import hashlib
import os
from pathlib import Path
import shutil
from tempfile import TemporaryDirectory
from urllib.request import urlopen
from zipfile import ZipFile


VERSION = "4.6.3"
RELEASE = f"{VERSION}-stable"
BASE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{RELEASE}"
ARCHIVE = f"Godot_v{RELEASE}_export_templates.tpz"
FILES = (
    "web_debug.zip",
    "web_release.zip",
    "web_nothreads_debug.zip",
    "web_nothreads_release.zip",
    "android_debug.apk",
    "android_release.apk",
    "android_source.zip",
    "linux_debug.x86_64",
    "linux_release.x86_64",
    "version.txt",
)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Reinstall existing templates")
    parser.add_argument("--check", action="store_true", help="Only check whether the required templates are installed")
    args = parser.parse_args()
    data_root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    destination = data_root / "godot" / "export_templates" / f"{VERSION}.stable"
    installed = all((destination / name).is_file() for name in FILES)
    if installed:
        installed = (destination / "version.txt").read_text().strip() == f"{VERSION}.stable"
    if args.check:
        if not installed:
            parser.exit(1, f"Templates missing at {destination}\n")
        print(f"Godot {VERSION} templates available at {destination}")
        return
    if installed and not args.force:
        print(f"Reusing installed Godot {VERSION} templates at {destination}")
        return

    # urllib preserves the machine's configured HTTPS proxy and CA trust.
    with urlopen(f"{BASE_URL}/SHA512-SUMS.txt", timeout=60) as response:
        checksums = response.read().decode("utf-8")
    expected = next((line.split()[0] for line in checksums.splitlines() if line.strip() and line.split()[-1] == ARCHIVE), None)
    if expected is None:
        parser.exit(1, "The official checksum manifest does not contain the template archive.\n")
    print(f"Downloading {ARCHIVE} (about 1.2 GB)...", flush=True)
    with TemporaryDirectory(prefix="piecepop-godot-") as temporary:
        archive_path = Path(temporary) / ARCHIVE
        checksum = hashlib.sha512()
        with urlopen(f"{BASE_URL}/{ARCHIVE}", timeout=120) as response, archive_path.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                checksum.update(chunk)
                output.write(chunk)
        if checksum.hexdigest() != expected:
            parser.exit(1, "SHA-512 verification failed. No templates were installed.\n")
        print("Official SHA-512 checksum verified.", flush=True)
        destination.mkdir(parents=True, exist_ok=True)
        with ZipFile(archive_path) as archive:
            for name in FILES:
                # Use exact upstream member names; never extract arbitrary paths.
                staged = Path(temporary) / name
                with archive.open(f"templates/{name}") as source, staged.open("wb") as output:
                    shutil.copyfileobj(source, output)
                if name.startswith("linux_"):
                    staged.chmod(0o755)
                shutil.move(str(staged), str(destination / name))
    print(f"Installed Godot {VERSION} export templates at {destination}")


if __name__ == "__main__":
    main()
