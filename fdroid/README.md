# Publishing Kulindeks on F-Droid

F-Droid builds apps **from source on its own servers** and distributes them for
free — no developer account, no fee. This folder holds the build recipe and a
step-by-step guide.

## What's already in place
- `fdroid/com.pankuleczka.kulindeks.yml` — the build recipe (metadata).
- `app/fastlane/metadata/android/{en-US,pl}/` — listing title, descriptions,
  icon and screenshots (F-Droid reads this automatically).
- GPL-3.0 license, tagged releases (`v0.1.1`, versionCode 2), reproducible
  Flutter build. No proprietary dependencies.

## Submit it (one-time)
1. Make a GitLab account and fork **https://gitlab.com/fdroid/fdroiddata**.
2. Copy the recipe into the fork:
   `metadata/com.pankuleczka.kulindeks.yml`
   (same contents as `fdroid/com.pankuleczka.kulindeks.yml` here).
3. Test the build locally with F-Droid's tools (Docker makes this easy):
   ```
   git clone https://gitlab.com/fdroid/fdroidserver
   # or: pip install fdroidserver
   cd fdroiddata
   fdroid readmeta
   fdroid lint com.pankuleczka.kulindeks
   fdroid build -v -l com.pankuleczka.kulindeks
   ```
4. Fix anything the build/lint reports (most likely: the exact `flutter@`
   srclib version and the `ndk:` tag — set them to values the current
   buildserver provides; see the TODOs in the recipe).
5. Open a Merge Request against `fdroiddata`. An F-Droid maintainer reviews it;
   expect a little back-and-forth on the recipe.

## Notes / likely review points
- **NonFreeNet anti-feature**: the app needs the university's proprietary
  backend, so it carries this label. That's fine — it's informational.
- **NDK**: `path_provider_android` and `shared_preferences_android` pull in
  `jni`, which compiles native code, so the build needs an NDK. The recipe
  declares one.
- **compileSdk 36 / build-tools**: `android/gradle.properties` disables AGP's
  auto-download, so the buildserver must already provide these. If it doesn't,
  either bump/lower `compileSdk` or drop that gradle flag for the F-Droid build.
- Each new release: add a new `Builds:` entry (new `versionName`/`versionCode`/
  `commit`) and bump `CurrentVersion`/`CurrentVersionCode`. With
  `UpdateCheckMode: Tags` + `AutoUpdateMode`, F-Droid can also pick up new tags
  automatically.

## Meanwhile (zero-friction distribution)
GitHub Releases already serve installable APKs, and users can get auto-updates
by subscribing to the repo in **Obtainium** — a good stopgap while the F-Droid
MR is in review.
