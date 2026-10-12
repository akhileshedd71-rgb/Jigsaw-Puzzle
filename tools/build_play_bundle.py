#!/usr/bin/env python3
"""Build a release AAB and sign it with a private upload key kept outside Git.

Requires Godot 4.6.3, its Android Gradle template, a full JDK, and the Android SDK.
Install the template with Godot's Project > Install Android Build Template command.
The Google Play preset intentionally exports unsigned; this helper signs a copy.
"""

from argparse import ArgumentParser
import hashlib
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--keystore", type=Path, required=True)
    parser.add_argument("--alias", default="piecepop-upload")
    parser.add_argument("--password-file", type=Path, help="Private UTF-8 password file; otherwise use PIECEPOP_UPLOAD_PASSWORD")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--java-home", type=Path, help="Full JDK containing javac and jarsigner")
    parser.add_argument("--output", type=Path, default=Path("builds/android/piecepop-1.0.0.aab"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    keystore = args.keystore.resolve()
    if not keystore.is_file():
        parser.error("The upload keystore does not exist.")
    password = args.password_file.read_text().strip() if args.password_file else os.environ.get("PIECEPOP_UPLOAD_PASSWORD", "")
    if not password:
        parser.error("Supply --password-file or PIECEPOP_UPLOAD_PASSWORD. Never put passwords on the command line.")
    env = os.environ.copy()
    if args.java_home:
        env["JAVA_HOME"] = str(args.java_home.resolve())
        env["PATH"] = str(args.java_home.resolve() / "bin") + os.pathsep + env.get("PATH", "")
    for executable in ("javac", "jarsigner", "keytool"):
        if not shutil.which(executable, path=env.get("PATH")):
            parser.error(f"A full JDK is required; {executable} is missing.")
    if not (root / "android/build/build.gradle").is_file():
        parser.error("Install the matching Android build template in Godot first.")
    output = args.output if args.output.is_absolute() else root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    unsigned = output.with_name(output.stem + "-unsigned.aab")
    signed = output.with_name(output.stem + "-signed.tmp.aab")
    for temporary in (unsigned, signed):
        temporary.unlink(missing_ok=True)
    # Godot must use the same full JDK in Editor Settings > Export > Android.
    # The signing secret is supplied only to keytool/jarsigner, never to Gradle.
    subprocess.run([args.godot, "--headless", "--path", str(root), "--export-release", "Google Play", str(unsigned)], cwd=root, env=env, check=True)
    if not unsigned.is_file() or unsigned.stat().st_size == 0:
        raise RuntimeError("Godot did not create an Android App Bundle.")
    env["PIECEPOP_UPLOAD_PASSWORD"] = password
    subprocess.run(["keytool", "-list", "-keystore", str(keystore), "-storepass:env", "PIECEPOP_UPLOAD_PASSWORD", "-alias", args.alias], env=env, check=True, stdout=subprocess.DEVNULL)
    shutil.copyfile(unsigned, signed)
    subprocess.run(["jarsigner", "-keystore", str(keystore), "-storepass:env", "PIECEPOP_UPLOAD_PASSWORD", "-keypass:env", "PIECEPOP_UPLOAD_PASSWORD", "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256", str(signed), args.alias], env=env, check=True)
    subprocess.run(["jarsigner", "-verify", str(signed)], env=env, check=True)
    signed.replace(output)
    with output.open("rb") as source:
        checksum = hashlib.file_digest(source, "sha256").hexdigest()
    output.with_suffix(".aab.sha256").write_text(checksum + "  " + output.name + "\n")
    print(f"Signed release bundle: {output}")
    print("Keep your upload key backup private and use the signed .aab in Play Console.")


if __name__ == "__main__":
    main()
