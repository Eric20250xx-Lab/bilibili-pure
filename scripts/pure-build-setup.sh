#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/pure-build-env.sh"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'This setup is for Apple Silicon macOS.' >&2; exit 1; }
cd "$PURE_PROJECT_ROOT"
mkdir -p .toolchain/downloads
fetch() {
  local url="$1" file="$2" sha="$3"
  if [[ ! -f "$file" ]] || [[ "$(shasum -a 256 "$file" | cut -d ' ' -f 1)" != "$sha" ]]; then
    curl --http1.1 -fL --retry 3 --connect-timeout 20 --speed-limit 1024 --speed-time 60 "$url" -o "$file.part"
    [[ "$(shasum -a 256 "$file.part" | cut -d ' ' -f 1)" == "$sha" ]] || { echo "Checksum mismatch: $file" >&2; exit 1; }
    mv "$file.part" "$file"
  fi
}
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  fetch https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.4-stable.zip .toolchain/downloads/flutter.zip c6af6fa1d64946167b8637ba4c5a7bb3b8574729a1ebe931decd4924dbab7061
  unzip -q .toolchain/downloads/flutter.zip -d .toolchain
fi
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  fetch 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.20.1_1.tar.gz' .toolchain/downloads/jdk.tar.gz 196d13ba5f10414bef7f6a05a9b3f00edacb18ebacef2b99485db9e2ee18f0e8
  tar -xzf .toolchain/downloads/jdk.tar.gz -C .toolchain
fi
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  fetch https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip .toolchain/downloads/android.zip 835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q .toolchain/downloads/android.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
# Java does not inherit the local HTTP proxy used by curl and pub.
if [[ "${HTTPS_PROXY:-}" =~ ^http://(127\.0\.0\.1|localhost):([0-9]+)/?$ ]] && [[ ! -f "$GRADLE_USER_HOME/gradle.properties" ]]; then
  mkdir -p "$GRADLE_USER_HOME"
  printf 'systemProp.https.proxyHost=%s\nsystemProp.https.proxyPort=%s\nsystemProp.http.proxyHost=%s\nsystemProp.http.proxyPort=%s\nsystemProp.http.nonProxyHosts=localhost|127.*\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" > "$GRADLE_USER_HOME/gradle.properties"
fi
mkdir -p "$GRADLE_USER_HOME/init.d"
if ! grep -q '^systemProp.org.gradle.internal.http.socketTimeout=' "$GRADLE_USER_HOME/gradle.properties" 2>/dev/null; then
  printf '\nsystemProp.org.gradle.internal.http.connectionTimeout=30000\nsystemProp.org.gradle.internal.http.socketTimeout=30000\n' >> "$GRADLE_USER_HOME/gradle.properties"
fi
cp "$PURE_PROJECT_ROOT/scripts/pure-build-maven-central.gradle" "$GRADLE_USER_HOME/init.d/maven-central-alias.gradle"
java -version
flutter --version
# sdkmanager presents the Android SDK licenses for acceptance before installation.
sdkmanager --sdk_root="$ANDROID_HOME" 'platform-tools' 'platforms;android-37.0' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'
"$PURE_PROJECT_ROOT/scripts/pure-build-patch.sh"
