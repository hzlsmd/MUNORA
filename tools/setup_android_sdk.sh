#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Install the Android SDK for MUNORA in an Ubuntu x86_64 Codespace.' \
    'Run: bash tools/setup_android_sdk.sh' \
    'Requires Flutter on PATH. SDK licenses are reviewed interactively.' \
    'Uses ANDROID_HOME when set; otherwise installs to $HOME/Android/Sdk.'
  exit 0
fi
if [[ $# -ne 0 || $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
  printf '%s\n' 'This installer supports Linux x86_64 with no arguments.' >&2
  exit 1
fi
if ! command -v flutter >/dev/null; then
  printf '%s\n' 'Install Flutter first and ensure flutter is available in this terminal.' >&2
  exit 1
fi

missing=false
for dependency in curl unzip javac sha256sum; do
  command -v "$dependency" >/dev/null || missing=true
done
if [[ $missing == true ]]; then
  sudo apt-get update
  sudo apt-get install -y curl unzip openjdk-17-jdk ca-certificates coreutils
fi

sdk_root="${ANDROID_HOME:-$HOME/Android/Sdk}"
mkdir -p "$sdk_root"
sdk_root="$(cd "$sdk_root" && pwd)"
export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
sdkmanager="$sdk_root/cmdline-tools/19.0/bin/sdkmanager"

if [[ ! -x "$sdkmanager" ]]; then
  if [[ -e "$sdk_root/cmdline-tools/19.0" ]]; then
    printf '%s\n' 'An incomplete cmdline-tools/19.0 directory already exists. Inspect it before retrying.' >&2
    exit 1
  fi
  download_dir="$(mktemp -d)"
  trap 'rm -rf -- "$download_dir"' EXIT
  curl --fail --location --retry 3 --connect-timeout 30 --max-time 600 \
    https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip \
    --output "$download_dir/tools.zip"
  # Google repository metadata identifies this archive as command-line tools 19.0.
  printf '%s  %s\n' 7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee \
    "$download_dir/tools.zip" | sha256sum --check --status
  unzip -q "$download_dir/tools.zip" -d "$download_dir/unpacked"
  mkdir -p "$sdk_root/cmdline-tools"
  mv "$download_dir/unpacked/cmdline-tools" "$sdk_root/cmdline-tools/19.0"
fi

printf '%s\n' 'Review the Android SDK licenses below. Accept only if you agree.'
"$sdkmanager" --sdk_root="$sdk_root" --licenses
"$sdkmanager" --sdk_root="$sdk_root" \
  'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'

for installed_file in platform-tools/adb platforms/android-36/android.jar build-tools/36.0.0/apksigner; do
  if [[ ! -f "$sdk_root/$installed_file" ]]; then
    printf 'SDK setup incomplete: missing %s. Check license acceptance and download errors.\n' "$installed_file" >&2
    exit 1
  fi
done

env_file="$HOME/.config/munora/android-env.sh"
mkdir -p "$(dirname "$env_file")"
{
  printf 'export ANDROID_HOME=%q\n' "$sdk_root"
  printf 'export ANDROID_SDK_ROOT=%q\n' "$sdk_root"
  printf 'export JAVA_HOME=%q\n' "$JAVA_HOME"
  printf 'export PATH="%s:$PATH"\n' '${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/19.0/bin'
} > "$env_file"
source_line='[ ! -f "$HOME/.config/munora/android-env.sh" ] || . "$HOME/.config/munora/android-env.sh"'
for profile in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if ! grep -Fqx "$source_line" "$profile" 2>/dev/null; then
    printf '\n%s\n' "$source_line" >> "$profile"
  fi
done
source "$env_file"
flutter config --android-sdk "$sdk_root"
adb version
printf '\n%s\n' 'Android SDK installed. In your current terminal, run:' \
  'source "$HOME/.config/munora/android-env.sh"' 'flutter doctor -v' \
  'An Android emulator/device must be configured separately.'
