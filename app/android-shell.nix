let
  pkgs = import <nixpkgs> {
    config.allowUnfree = true;
    config.android_sdk.accept_license = true;
  };
  android = pkgs.androidenv.composeAndroidPackages {
    cmdLineToolsVersion = "11.0";
    platformToolsVersion = "37.0.1";
    buildToolsVersions = [ "34.0.0" "35.0.0" "36.0.0" ];
    platformVersions = [ "34" "35" "36" ];
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ];
    cmakeVersions = [ "3.22.1" ];
    includeSystemImages = false;
    includeEmulator = false;
  };
  sdk = "${android.androidsdk}/libexec/android-sdk";
in
pkgs.mkShell {
  buildInputs = [ pkgs.flutter pkgs.jdk17 android.androidsdk ];
  ANDROID_SDK_ROOT = sdk;
  ANDROID_HOME = sdk;
  ANDROID_NDK_ROOT = "${sdk}/ndk/28.2.13676358";
  JAVA_HOME = pkgs.jdk17.home;
  # NixOS: gradle's maven aapt2 is a generic ELF that won't run — use the SDK's.
  GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdk}/build-tools/36.0.0/aapt2";
}
