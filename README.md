# 🏃‍♂️ Territory Runner

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-%23039BE5.svg?style=for-the-badge&logo=Firebase&logoColor=white" alt="Firebase" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License" />
</div>

<br>

**Territory Runner** is a visually stunning, location-based run tracking application built with Flutter. Track your runs, claim geographic blocks, and keep your streak alive with minimal noise and maximum momentum. 

Think of it as fitness meets gaming: sweat it out in the real world to conquer your virtual territory!

---

## ✨ Key Features

- **📍 Live Location Tracking:** Precise and continuous tracking of your current position on the map using `geolocator` and `flutter_map`.
- **🎮 Territory Claiming:** Turn your city into a game board! Claim areas based on your running routes and expand your domain.
- **🏃‍♂️ Advanced Runner Profiles:** Track your total distance, level up by earning XP, and unlock special badges as you hit new milestones.
- **🎨 Premium Dark UI:** A sleek, immersive dark-themed interface inspired by modern fitness apps, featuring micro-animations, glowing accents, and haptic feedback.
- **🤖 AI Integration:** Powered by `google_generative_ai` for smart insights and dynamic interactions.
- **☁️ Cloud Sync:** Securely save your progress, territories, and profile data in real-time with Firebase.

## 🛠️ Tech Stack & Architecture

- **Frontend:** [Flutter](https://flutter.dev/) & Dart
- **Maps & Location:** `flutter_map`, `latlong2`, `geolocator`, `maps_toolkit`
- **Backend & Database:** Firebase Auth, Cloud Firestore
- **Local Storage:** Hive
- **Additional Tools:** `audioplayers` (Audio), `vibration` (Haptics)

---

## 🚀 Getting Started

Follow these instructions to set up the project locally on your machine.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Version 3.13.2 or higher)
- Android Studio or Xcode (for emulation/compilation)
- A Firebase project setup (Required for Auth & Firestore)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ayush-00-hui/Territory-Runner-Game.git
   cd Territory-Runner-Game
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Make sure you have your `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) configured properly from your Firebase Console.

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📸 Screenshots
*(Coming Soon - Add your app screenshots here to showcase the beautiful UI!)*

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Ayush-00-hui/Territory-Runner-Game/issues) if you want to contribute.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<div align="center">
  <i>Built with ❤️ for runners and gamers.</i>
</div>
