# Territory Runner — Store Readiness & Compliance Specification

> [!IMPORTANT]
> **Store Compliance Notice**: This document specifies the implementation-level privacy, disclosure, and security controls for Google Play Console and Apple App Store submissions. This application is currently in development and staging; **no build is claimed to be published or approved yet**.

---

## 1. Application Identity Summary

| Platform | Attribute | Configured Value | Source File |
| :--- | :--- | :--- | :--- |
| **Android** | Namespace | `com.territoryrunner.app` | [android/app/build.gradle.kts](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/build.gradle.kts) |
| **Android** | Application ID | `com.territoryrunner.app` | [android/app/build.gradle.kts](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/build.gradle.kts) |
| **Android** | App Label | `Territory Runner` | [android/app/src/main/AndroidManifest.xml](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/src/main/AndroidManifest.xml) |
| **Android** | Min SDK / Target SDK | Min: 21 / Target: 34 (Android 14) | [android/app/build.gradle.kts](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/build.gradle.kts) |
| **iOS** | Bundle Identifier | `com.territoryrunner.app` | [ios/Runner.xcodeproj/project.pbxproj](file:///c:/Users/AYUSH/Desktop/territory_runner/ios/Runner.xcodeproj/project.pbxproj) |
| **iOS** | CFBundleDisplayName | `Territory Runner` | [ios/Runner/Info.plist](file:///c:/Users/AYUSH/Desktop/territory_runner/ios/Runner/Info.plist) |
| **iOS** | CFBundleName | `Territory Runner` | [ios/Runner/Info.plist](file:///c:/Users/AYUSH/Desktop/territory_runner/ios/Runner/Info.plist) |

---

## 2. Background Location Prominent Disclosure

Both Google Play Policy (Location in the Background) and Apple App Store Guidelines (Guideline 5.1.1) mandate a clear, in-app prominent disclosure presented to the runner **immediately before** requesting background location access (`ACCESS_BACKGROUND_LOCATION` / `NSLocationAlwaysAndWhenInUseUsageDescription`).

### 2.1 Where the Disclosure Appears
The prominent disclosure is triggered via the custom bottom sheet component:
- **Component**: `PermissionPrimerSheet.backgroundLocation`
- **Source Code**: [lib/ui/widgets/permission_primer_sheet.dart](file:///c:/Users/AYUSH/Desktop/territory_runner/lib/ui/widgets/permission_primer_sheet.dart#L322-L349)
- **Trigger Sequence**:
  1. Runner starts an active session or enables locked-screen tracking in Run Settings.
  2. The custom `PermissionPrimerSheet` is displayed modally with a dark scrim, **prior** to any operating system dialog.
  3. The runner must explicitly tap `"ALLOW ALL-TIME GPS"` to trigger the platform prompt, or tap `"MAYBE LATER"` to cancel.

### 2.2 Exact Prominent Disclosure Text

```
Title:
BACKGROUND TRACKING SENSING

Subtitle:
CONTINUOUS ENCLOSURE RADAR

Body:
To record loops while your phone is locked in your pocket or when using AMOLED battery saver, background location access is required. No telemetry is logged when not running.

Features Highlighted:
1. Locked-Screen Run Capture: Run with screen turned off to save battery without losing path points.
2. AMOLED Minimalist Display: Seamlessly pairs with black-out AMOLED HUD during active runs.
3. Autonomous Run Recovery: Restores state if OS suspends app mid-conquest.

Action Buttons:
[ ALLOW ALL-TIME GPS ]    [ MAYBE LATER ]
```

---

## 3. Foreground Service Type Justification (Android 14+)

In accordance with Android 14 (API level 34) Foreground Service type policies:

### 3.1 Manifest Declaration
In [android/app/src/main/AndroidManifest.xml](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/src/main/AndroidManifest.xml#L44-L48):
```xml
<service
    android:name="com.baseflow.geolocator.GeolocatorLocationService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location" />
```

### 3.2 Google Play Justification Statement
- **Service Type**: `foregroundServiceType="location"`
- **User-Initiated Trigger**: The foreground service starts solely when the athlete explicitly taps the "START RUN" action button on the Map interface.
- **Purpose**: Real-time GPS path recording, pace calculation, and polygon loop enclosure detection while the user’s screen is locked or the app is temporarily in the background.
- **User Visibility**: While running, a non-dismissible persistent notification is displayed in the Android system drawer showing real-time live run telemetry: `"Tracking your running route in the background..."`.
- **Termination**: The service is immediately stopped when the runner hits "Finish Run" or "Discard".

---

## 4. Data Safety & Privacy Matrix

### 4.1 Google Play Data Safety Section

| Data Category | Data Type | Collected? | Shared? | Purpose | Ephemeral / Stored | Linked to User? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Location** | Precise Location | Yes | No | App functionality (recording runs, polygon loop detection, live presence) | Stored (GPS points in run records) & Ephemeral (real-time WebSocket presence) | Yes (User account) |
| **Personal Info** | Name / Display Name | Yes | No | App functionality (leaderboards, duels, multiplayer display) | Stored (PostgreSQL `users` table) | Yes |
| **Personal Info** | User IDs | Yes | No | Authentication & account management | Stored | Yes |
| **Personal Info** | Email address | Yes | No | Firebase Authentication / account recovery | Stored in Firebase Auth | Yes |
| **Fitness** | Fitness info (distance, pace, area) | Yes | No | App functionality, analytics, territory scoring | Stored (`runs` and `territories` tables) | Yes |
| **App Info** | Crash logs / Diagnostics | Yes | No | App stability (when Crashlytics is configured) | Stored (Crashlytics) | No |
| **Device IDs** | Device Token | Yes | No | Push notifications for territory conquests and duel alerts | Stored (`device_tokens` table) | Yes |

### 4.2 Apple App Privacy Nutrition Label
- **Data Used to Track You**: None (No data is shared with third-party data brokers or ad networks).
- **Data Linked to You**: Location (Precise), User Content, Identifiers (User ID), Usage Data.
- **Data Not Linked to You**: Diagnostics and performance metrics.

---

## 5. Account Deletion & Data Purge Path

Both Google Play and Apple App Store mandate a straightforward in-app and web-based account deletion pathway.

### 5.1 In-App Deletion Path
- **Navigation**: Settings Screen -> Account & Security -> "Delete Account".
- **Confirmation Flow**: Multi-step destructive confirmation dialog warning the runner that all territories, run history, and stats will be irreversibly purged.
- **Execution**:
  - Revokes client session and deletes local Hive caches (`territories_v3`, `profile`, `active_run_recovery`).
  - Calls backend deletion endpoint `DELETE /v1/me`.
  - Calls `FirebaseMessaging.instance.deleteToken()`.
  - Invokes `FirebaseAuth.instance.currentUser?.delete()`.

### 5.2 Database Cascade Architecture
The backend PostgreSQL schema enforces strict cascading deletes across all user foreign keys:
- `territories`: `user_id ... ON DELETE CASCADE`
- `runs`: `user_id ... ON DELETE CASCADE`
- `device_tokens`: `user_id ... ON DELETE CASCADE`
- `friends` & `duels`: `user_id ... ON DELETE CASCADE`
- `privacy_zones`: `user_id ... ON DELETE CASCADE`

Purging the user record completely obliterates all associated spatial polygons, GPS breadcrumbs, device push tokens, and social records.

### 5.3 Web Deletion Request URL (Placeholder)
- Public web deletion request portal: `https://territoryrunner.app/privacy/delete-account` (Placeholder)
- Users can submit their registered email address to request account and data removal within 30 days without installing the app.

---

## 6. Release Signing & ProGuard/R8 Configuration

### 6.1 Release Signing Configuration
Release builds require a dedicated signing keystore. Debug signing has been completely excised from the `release` build type in [android/app/build.gradle.kts](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/build.gradle.kts).

To generate a new production release keystore:
```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Create `android/key.properties` (strictly git-ignored):
```properties
keyAlias=upload
keyPassword=<YOUR_KEY_PASSWORD>
storeFile=upload-keystore.jks
storePassword=<YOUR_KEYSTORE_PASSWORD>
```

### 6.2 R8 Minification & Keep Rules
R8 code shrinking and resource shrinking are enabled for all release builds:
- `isMinifyEnabled = true`
- `isShrinkResources = true`
- ProGuard rules: [android/app/proguard-rules.pro](file:///c:/Users/AYUSH/Desktop/territory_runner/android/app/proguard-rules.pro) preserves Flutter engine wrappers, Geolocator background service, Firebase, and serialization classes.

---

## 7. Content Rating & Policy Notes (IARC Questionnaire)

- **Violence / Sexual Content / Profanity**: None.
- **Real-World Athletic Caution**: The app includes tactical safety disclaimers, real-world traffic warnings, and privacy zones to keep athletes safe in urban running environments.
- **User Interactions**: Real-time multiplayer presence (suppressed within user-configured privacy bubbles) and public territory ownership.
- **Privacy Policy URL**: `https://territoryrunner.app/privacy` (Placeholder)
- **Support Contact**: `support@territoryrunner.app`
