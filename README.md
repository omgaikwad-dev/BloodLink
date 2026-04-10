<div align="center">
  <h1>🩸 BloodLink AI</h1>
  <p><strong>Emergency Blood Network System powered by AI</strong></p>
  
  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
  [![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)](https://firebase.google.com/)
  [![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
</div>

---

## 📖 Overview

**BloodLink AI** is a state-of-the-art Flutter application built to streamline the emergency blood donation network. Utilizing machine learning, real-time location tracking, and an extensive Firebase backend, BloodLink bridges the gap between blood donors, hospitals, and blood banks when time matters most.

With our integrated AI features (Demand Prediction, Emergency Classifier, Fraud Prevention), BloodLink is engineered to save lives faster and smarter.

## ✨ Key Features

- 👤 **Intelligent Dashboard**: View live statistics, requests, and medical records securely.
- 🏥 **Emergency Blood Requests**: Quickly broadcast urgent requests directly to relevant, nearby, and eligible donors.
- 🎯 **AI Matching & Classification**: Python-based AI API intelligently predicts demand and classifies the severity of requests.
- 📍 **Real-time Location Tracking**: Free and interactive mapping interface with OpenStreetMap (`flutter_map`) to track donor arrival locations.
- 💬 **Push Notifications**: Receive real-time push alerts powered by Firebase Cloud Messaging.
- 📊 **Dynamic Data Visualization**: Integrated `fl_chart` for monitoring trends and demand metrics.
- 🛡️ **Advanced Fraud Prevention**: Dedicated service layer designed to enforce security and valid requests.
- 📄 **Medical PDF Support**: Complete medical records interface with seamless PDF printing support.

## 🛠️ Technology Stack

- **Frontend**: [Flutter](https://flutter.dev) (Dart), Provider (State Management), Google Fonts, Shimmer, Flutter Animate.
- **Backend / DB**: Firebase Auth, Cloud Firestore, Firebase Messaging.
- **Maps / Location**: `flutter_map`, OpenStreetMap, geolocator, geocoding.
- **AI Middleware**: Python backend API (`ai_api/main.py`).

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.11.4)
- Dart SDK
- Android Studio / Xcode
- Python (for running AI Models API)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/BloodLink_Ai.git
   cd BloodLink_Ai
   ```

2. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Ensure you have configured your respective `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) via the Firebase Console and placed them in their respective native directories.

4. **Run the AI Backend:**
   If you wish to test the AI classifiers and models locally:
   ```bash
   cd ai_api
   pip install -r requirements.txt # Adjust according to actual packages
   python main.py
   ```

5. **Run the App:**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
 ├── core/
 │    ├── constants/       # App-wide constants (themes, keys, etc.)
 │    └── services/        # Firebase, Fraud Prevention, Predictors
 ├── screens/
 │    ├── ai/              # AI powered screens (Demand Prediction, Emergency)
 │    ├── donor/           # Donor modules and dashboards
 │    └── profile/         # Account management, privacy, & security
 ├── widgets/              # Reusable UI components
 └── main.dart             # Application entry point
ai_api/
 └── main.py               # ML API (Demand prediction & classification)
```

## 🔒 Privacy & Security

Your medical data safety is our highest priority. The application comes equipped with `local_auth` bindings for secure access and detailed user privacy screens giving full control over linked devices and medical records. All data transmitted is securely encrypted over HTTPS and Firebase.

## 📄 License

This project is open-source. Please see the [LICENSE](LICENSE) file for more information.

---
*Built with ❤️ to save lives.*
