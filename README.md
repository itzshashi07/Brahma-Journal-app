# 🕉️ Brahma Journal — Spiritual Wellness & Mindfulness Companion

Brahma Journal is a premium, youth-attractive, and peaceful mindfulness application built using **Flutter**. Designed to help users track their spiritual progress, build daily meditation habits, share reflections, and analyze their emotional patterns in a safe, peaceful environment.

---

## 🌟 Key Features

### 📔 1. Calming Onboarding & Welcome Sanctuary
- **6-Slide Feature Showcase**: Engaging visuals explaining journal entries, audio meditations, affirmations, anonymous boards, community streaks, and mood analytics.
- **Rotating Quote Ticker**: Dynamic quote display carousel featuring peaceful mindfulness quotes on a beautiful dark-mode gradient layout.

### ✍️ 2. Mindful Journaling (Focus Forward)
- **12 Comprehensive Entry Fields**: Log daily reflections, actions, values, and sleep parameters.
- **Minimalist Mood Wrap Buttons**: Clean outline mood selection tags ("Restless", "Heavy", "Neutral", "Calm", "Joyful").
- **Past Entry Protection**: View historical data as read-only to analyze past paths while ensuring changes can only be made for the current day.

### 🧘 3. Audio Meditation Sanctuary
- Timer-guided meditation sessions.
- High-quality, serene background sound profiles (Forest, Bowls, Waves) loaded dynamically from Cloud Storage.

### 💖 4. Serene Affirmations & Mantras
- Daily affirmation progress tracking.
- peaceful mantras designed for grounding the mind.

### 🗣️ 5. Anonymous Thoughts Board
- Safely share and read anonymous spiritual thoughts.
- Connect and exchange support messages with zero judgment.

### 🏆 6. Streak Leaderboards (Community)
- Build daily journaling streaks.
- Non-disruptive ranking views utilizing premium metallic circular badges instead of emojis.

### 📊 7. Deep Mood Analytics
- Interactive mood and habit charts using `fl_chart`.
- Visualize historical mental patterns and identify peace triggers.

---

## 💳 Payment & Subscriptions Integration
Brahma Journal integrates **Razorpay Subscriptions (Auto-Debit)** for registration:
- **Monthly Plan**: ₹49/month
- **Annual Plan**: ₹399/year (Save 32%)
- **Dynamic Mandate**: Uses Razorpay subscription REST API dynamically to fetch mandate IDs and open the secure UPI Autopay / Card mandate checkout.
- **Fallback Mode**: Automatically transitions to a standard test amount payment if subscription Plan IDs are unconfigured locally.

---

## ✉️ Automated Support & Notifications
- **Resend REST API Integration**:
  - **Signup Alerts**: Triggers automated receipt metadata emails (Name, Email, Plan, payment reference ID) to the Admin upon registration.
  - **Support tickets**: Contact queries submitted inside the app are instantly dispatched to the Admin inbox.
- Expandable FAQs & Direct Support Helpline: `+91 8078633912`.

---

## 🛠️ Installation & Setup

### 1. Clone & Prepare Environment Variables
Duplicate `.env.example` to `.env` in the root of the project:
```bash
cp .env.example .env
```
Update your keys:
- **Firebase Keys**: API keys, App ID, and Project IDs.
- **Razorpay Keys**: Test/Live Key ID, Key Secret, and Subscription Plan IDs.
- **Resend Email Settings**: Resend API Token and admin destination email.

### 2. Configure Firebase Configs
1. Android: Place `google-services.json` inside `android/app/`.
2. iOS: Place `GoogleService-Info.plist` inside `ios/Runner/`.

### 3. Run the App
Get dependencies:
```bash
flutter pub get
```
Run on your connected emulator or device:
```bash
flutter run
```

---

## 📁 Project Architecture
```
lib/
├── main.dart                 # Navigation, Routing Guards & Dotenv Initialization
├── firebase_options.dart     # Auto-generated Firebase client configs
├── core/
│   ├── constants/            # Configuration constants & dynamic dotenv getters
│   └── theme/                # Spiritual dark violet theme parameters
├── models/                   # Profile, Entry, and Thoughts models
├── services/                 # Firebase, Razorpay, Resend Email API integrations
├── providers/                # Auth & Journal state management providers
└── screens/                  # 13 Premium layout views
```
