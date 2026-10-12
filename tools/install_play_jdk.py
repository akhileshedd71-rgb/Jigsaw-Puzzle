#!/usr/bin/env python3
"""Install the checksum-verified Temurin 21 JDK used for the release build (Linux x64)."""

from argparse import ArgumentParser
import hashlib
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
from tempfile import TemporaryDirectory
from urllib.request import urlopen

VERSION = "21.0.12.1+1"
ARCHIVE = "OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz"
URL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/" + ARCHIVE


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "AMD64"):
        parser.error("Use a full JDK for your platform. This installer is for Linux x64.")
    destination = args.destination.resolve()
    if (destination / "bin/javac").is_file():
        version = subprocess.check_output([str(destination / "bin/javac"), "-version"], text=True).strip()
        if version != "javac " + VERSION.split("+")[0]:
            parser.error(f"Existing compiler is {version}; refusing to replace it.")
        print(f"Reusing full JDK: {destination} ({version})")
        return
    if destination.exists():
        parser.error("Destination exists without javac; select an empty destination.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(URL + ".sha256.txt", timeout=60) as response:
        expected = response.read().decode().split()[0].lower()
    if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
        raise RuntimeError("The official JDK checksum response is invalid.")
    with TemporaryDirectory(prefix="piecepop-jdk-", dir=destination.parent) as temporary:
        archive = Path(temporary) / ARCHIVE
        digest = hashlib.sha256()
        print(f"Downloading Temurin JDK {VERSION}...", flush=True)
        with urlopen(URL, timeout=120) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
        if digest.hexdigest() != expected:
            raise RuntimeError("Official JDK checksum verification failed.")
        extracted = Path(temporary) / "extracted"
        extracted.mkdir()
        with tarfile.open(archive) as package:
            package.extractall(extracted, filter="data")
        folders = list(extracted.iterdir())
        if len(folders) != 1 or not (folders[0] / "bin/javac").is_file():
            raise RuntimeError("Unexpected JDK archive layout.")
        shutil.move(str(folders[0]), destination)
    subprocess.run([str(destination / "bin/javac"), "-version"], check=True)
    print(f"Verified full JDK installed: {destination}")


if __name__ == "__main__":
    main()
