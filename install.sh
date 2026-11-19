#!/usr/bin/env bash
# Download a skigard release, verify its SHA-256, put it on PATH. Used by action.yml; runs on Linux, macOS and Windows
# (Git Bash). Inputs arrive as environment variables, never interpolated into the script.
set -euo pipefail
version="${INPUT_VERSION:-}"; want="${INPUT_SHA256:-}"; base="${INPUT_BASE_URL:-}"
die() { echo "::error::skigard-action: $*" >&2; exit 1; }

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "version must look like 0.1.0 (got '$version'); there is no 'latest' on purpose"
[ -z "$want" ] || [[ "$want" =~ ^[0-9a-fA-F]{64}$ ]] || die "sha256 must be 64 hex characters"

case "${RUNNER_OS:-$(uname -s)}" in
  Linux) os=linux; ext=tar.gz; exe=skigard ;;
  macOS | Darwin) os=darwin; ext=tar.gz; exe=skigard ;;
  Windows | MINGW* | MSYS* | CYGWIN*) os=windows; ext=zip; exe=skigard.exe ;;
  *) die "unsupported OS ${RUNNER_OS:-$(uname -s)}" ;;
esac
case "${RUNNER_ARCH:-$(uname -m)}" in
  X64 | x86_64 | amd64 | AMD64) arch=amd64 ;;
  ARM64 | arm64 | aarch64) arch=arm64 ;;
  *) die "unsupported architecture ${RUNNER_ARCH:-$(uname -m)}" ;;
esac

if [ -z "$base" ]; then
  base="https://github.com/ambierhq/skigard/releases/download/v${version}"
else
  base="${base%/}"
  case "$base" in
    https://* | file://* | http://localhost[:/]* | http://127.0.0.1[:/]*) ;;
    *) die "base-url must be https://, file://, or http://localhost / 127.0.0.1 (got '$base')" ;;
  esac
fi

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

tmp="$(mktemp -d)"
file="skigard_${version}_${os}_${arch}.${ext}"
echo "downloading $base/$file"
curl -fsSL --retry 3 --proto '=https,http,file' -o "$tmp/$file" "$base/$file" || die "cannot download $base/$file"
curl -fsSL --retry 3 --proto '=https,http,file' -o "$tmp/checksums.txt" "$base/checksums.txt" || die "cannot download $base/checksums.txt"

expected="$(awk -v f="$file" '$2 == f {print $1}' "$tmp/checksums.txt")"
[ -n "$expected" ] || die "checksums.txt has no entry for $file"
actual="$(sha256 "$tmp/$file")"
[ "$actual" = "$expected" ] || die "checksum mismatch for $file: checksums.txt says $expected, download is $actual"
if [ -n "$want" ]; then
  want="$(printf '%s' "$want" | tr 'A-F' 'a-f')"
  [ "$actual" = "$want" ] || die "sha256 input mismatch for $file: pinned $want, download is $actual"
fi
echo "sha256 ok: $actual"

dest="${RUNNER_TEMP:-$tmp}/skigard-${version}/bin"
mkdir -p "$dest"
case "$ext" in
  tar.gz) tar -xzf "$tmp/$file" -C "$dest" "$exe" ;;
  zip)
    if command -v unzip >/dev/null 2>&1; then unzip -q -o "$tmp/$file" "$exe" -d "$dest"
    elif command -v 7z >/dev/null 2>&1; then 7z x -y "-o$dest" "$tmp/$file" "$exe" >/dev/null
    else powershell.exe -NoProfile -Command "Expand-Archive -Force -Path '$(cygpath -w "$tmp/$file")' -DestinationPath '$(cygpath -w "$dest")'"
    fi ;;
esac
[ -f "$dest/$exe" ] || die "$exe not found in $file"
chmod +x "$dest/$exe"

pathdir="$dest"; if command -v cygpath >/dev/null 2>&1; then pathdir="$(cygpath -w "$dest")"; fi
if [ -n "${GITHUB_PATH:-}" ]; then echo "$pathdir" >> "$GITHUB_PATH"; fi
export PATH="$dest:$PATH"
v="$("$dest/$exe" version)"
echo "installed: $v"
if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "version=$v" >> "$GITHUB_OUTPUT"; fi
