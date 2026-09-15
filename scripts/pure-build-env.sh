#!/usr/bin/env bash
# Source this file to use only this project's Android toolchain.
PURE_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FLUTTER_ROOT="$PURE_PROJECT_ROOT/.toolchain/flutter"
export PUB_CACHE="$PURE_PROJECT_ROOT/.toolchain/pub-cache"
export JAVA_HOME="$PURE_PROJECT_ROOT/.toolchain/jdk-17.0.20.1+1/Contents/Home"
export ANDROID_HOME="$PURE_PROJECT_ROOT/.toolchain/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PURE_PROJECT_ROOT/.toolchain/android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export GRADLE_USER_HOME="$PURE_PROJECT_ROOT/.toolchain/gradle"
export PATH="$FLUTTER_ROOT/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
# Avoid the observed HTTP/2 clone cancellations without changing Git config files.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=http.version
export GIT_CONFIG_VALUE_0=HTTP/1.1
# Flutter may discover Android Studio first; pin Gradle's actual build JVM.
export GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.java.home=$JAVA_HOME"
