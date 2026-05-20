# Bill Reminder App

This Flutter app now includes **Firebase Authentication (Email/Password)** while still supporting **Continue as Guest** with local SQLite data.

## What was integrated

- `firebase_core` and `firebase_auth` dependencies
- Firebase initialization in `lib/main.dart`
- Email/password login + sign-up flow in `lib/screens/login_screen.dart`
- Firebase sign-out in `lib/screens/profile_screen.dart`
- Android Google Services Gradle plugin setup

## Firebase setup you still need to do

> The app code is ready, but Firebase project files must be linked from your own Firebase project.

### 1) Create/select a Firebase project

Use the [Firebase Console](https://console.firebase.google.com/) and create a project (or use an existing one).

### 2) Enable Email/Password authentication

In Firebase Console:

1. Go to **Authentication**
2. Open **Sign-in method**
3. Enable **Email/Password**

### 3) Configure Flutter platforms with FlutterFire CLI (recommended)

From project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select your Firebase project and target platforms (Android/iOS/Web as needed).

This generates `lib/firebase_options.dart` and platform config.

### 4) Connect generated options in `main.dart`

After `flutterfire configure`, update initialization to use generated options:

```dart
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 5) If you are not using FlutterFire CLI (manual files)

- **Android:** download and place `google-services.json` in `android/app/google-services.json`
- **iOS:** download and place `GoogleService-Info.plist` in `ios/Runner/GoogleService-Info.plist` (and ensure it is added to Runner target)
- **Web:** configure Firebase web options (FlutterFire CLI is easiest)

## Run

```bash
flutter pub get
flutter run
```

## Notes

- Guest mode still works and keeps data local to the device.
- Firebase Auth login/sign-up now uses real backend authentication.
