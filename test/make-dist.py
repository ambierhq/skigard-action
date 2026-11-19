#!/usr/bin/env python3
"""Package a locally built skigard binary like GoReleaser does, for this action's tests.
usage: make-dist.py BINARY VERSION OUTDIR OS ARCH     (OS: linux|darwin|windows, ARCH: amd64|arm64)
"""
import hashlib, os, sys, tarfile, zipfile

binary, version, out, goos, goarch = sys.argv[1:6]
os.makedirs(out, exist_ok=True)
ext = "zip" if goos == "windows" else "tar.gz"
name = f"skigard_{version}_{goos}_{goarch}.{ext}"
exe = "skigard.exe" if goos == "windows" else "skigard"
path = os.path.join(out, name)
if ext == "zip":
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(binary, exe)
else:
    with tarfile.open(path, "w:gz") as t:
        t.add(binary, exe)
digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
with open(os.path.join(out, "checksums.txt"), "a") as f:
    f.write(f"{digest}  {name}\n")
print(digest)
