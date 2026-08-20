# Implementation Plan - Rectify Gradle, AGP, Kotlin, and Supabase Build Errors

The build is failing due to outdated build tools (Gradle, AGP, Kotlin), a breaking change in the `supabase_flutter` API, and missing configuration for `flutter_local_notifications`.

## Proposed Changes

### Supabase Service
#### [MODIFY] [supabase_service.dart](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/lib/core/services/supabase/supabase_service.dart)
- Change `publishableKey` to `anonKey` in `Supabase.initialize` to match the latest API.

### Android Build Configuration
#### [MODIFY] [gradle-wrapper.properties](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/android/gradle/wrapper/gradle-wrapper.properties)
- Upgrade Gradle from `8.10.2` to `8.14.0`.

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/android/settings.gradle.kts)
- Upgrade Android Gradle Plugin (AGP) from `8.7.0` to `8.11.1`.
- Upgrade Kotlin Gradle Plugin (KGP) from `1.8.22` to `2.2.20`.

#### [MODIFY] [app/build.gradle.kts](file:///C:/Users/lmxbl/Documents/ASElectric/volt_core/android/app/build.gradle.kts)
- Enable Core Library Desugaring.
- Add `com.android.tools:desugar_jdk_libs:2.1.2` dependency.
- Ensure `compileOptions` and `kotlinOptions` are correctly set for desugaring.

## Verification Plan
### Automated Tests
- Run `flutter build apk` (or the user can attempt to run the app again).
- Verify that the Supabase initialization compiles correctly.
- Verify that Gradle task `:app:checkDebugAarMetadata` passes.
