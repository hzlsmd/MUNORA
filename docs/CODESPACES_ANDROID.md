# Android SDK in Codespaces

In your Ubuntu x86_64 Codespace, with Flutter already on PATH, run:

```bash
bash tools/setup_android_sdk.sh
source "$HOME/.config/munora/android-env.sh"
flutter doctor -v
```

Review the license prompts and accept only if you agree. The installer adds Java
and download utilities through sudo/apt if missing. It downloads Google's pinned
command-line tools 19.0 with a SHA-256 check, then uses sdkmanager to install
platform-tools, Android platform 36 and build-tools 36.0.0. These match MUNORA's
Flutter 3.47.9 compile SDK. It uses ANDROID_HOME if set, otherwise
`$HOME/Android/Sdk`; SDK files stay outside the Git repository.

The script configures Flutter and adds one environment-file source line to Bash
and Zsh startup files. It can be rerun after an interrupted package download.
It preserves an existing command-line tools installation; an incomplete 19.0
directory needs manual inspection. A Codespace rebuild may remove home-directory
SDK installations; rerun the script after rebuilding if needed.

This installs build tools, not a running emulator. `flutter devices` will not
show an Android phone until one is connected or an emulator is configured.
Hardware-accelerated emulators require accessible KVM; it is not guaranteed in
Codespaces. For an interactive emulator, use Android Studio on your Windows
computer with a local Flutter checkout.

To build a debug APK from the project root after setup:

```bash
flutter pub get
flutter build apk --debug
```

The first Android build may download Gradle, Maven dependencies and Flutter's
pinned NDK (28.2.13676358), requiring additional time and disk space. Debug builds
do not need a release keystore. Release builds require the signing configuration
in the [release checklist](audit/RELEASE_CHECKLIST.md#android-signing).

Missing Chrome/Linux-desktop tools in `flutter doctor` do not block Android
builds. Installing this SDK does not configure MUNORA's live-weather endpoint.
