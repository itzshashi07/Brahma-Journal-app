# InnenFlow — a quieter place to think

InnenFlow is a Flutter app for people trying to build a steadier inner life: a daily journal, guided meditation, an anonymous board, and analytics that answer the one question a mood tracker cannot — *am I actually doing the work I said mattered to me?*

It is deliberately **religion-neutral**. The practices here come from traditions all over the world, but nothing in the app asks you to belong to any of them. Anyone can use it and recognise themselves in it.

---

## 🌟 What is in it

### ✍️ Write
- **Journal** — a structured daily entry: mood, energy, what helped, what got in the way, and a free-text reflection. Past days are read-only; you can look back, but you can only write today.
- **Affirmations** — short phrases with a stated reason for each, so it reads as practice rather than as slogans.
- **Open Board** — post a reflection anonymously and reply to other people's. Posts fade after a month. Nothing on the board carries your account id, including replies.

### 📖 Read
- **Wisdom for Real Life** — organised by the situation you are actually in rather than by chapter, so it is findable at 2am. Sanskrit is present for those who want it and collapsed for those who do not.
- **Articles** — written by members, with comments.
- **Library** — books and long reads, page-by-page in-app.

### 🌿 Unwind
- **Meditation** — timed sittings, a technique library, and a short quiz that recommends one based on how you actually feel right now.
- **Game Zone** — memory, reflex, attention and puzzle games. Focus minutes are tracked separately from meditation minutes so neither number lies.

### 📊 Track
- **Your Patterns** — mood over time, meditation minutes, and a consistency chart for your own daily checklist.
- **Streak Board** and **Game Ranks** — leaderboards, recomputed server-side so they cannot be inflated from a patched client.

### 🎯 Your daily checklist
Pick what you are working on (student, engineer, musician, athlete, or none of the above) and the journal offers a short list of concrete things to tick. **Add your own items too** — the presets are a starting point, not a definition. Everything you tick, preset or custom, feeds the consistency chart.

### 🧘 1-to-1 counselling
A real conversation with a real person — chat or video, with voice notes. The entire transcript, including any audio, is destroyed two hours after the session ends.

---

## 💳 Payments

**Currently off.** Everything is free for everyone, with no trial clock and no countdown.

The Razorpay integration is intact and untouched — subscription creation, HMAC verification, entitlement writes — it is simply not reached. Flip `AppConstants.paymentsEnabled` back to `true` and ship a build to bring it back exactly as it was.

Free access ends when a human decides it ends. There is no date in the code that will decide it for you.

---

## 🔐 Security model

The app is a public binary; assume everything in it is readable and every request it makes can be forged. So the three things that matter live on the server:

| Concern | Where it lives |
| --- | --- |
| Payment creation & verification | Cloud Functions, Razorpay secret in Secret Manager |
| Entitlement (`premium`, `purchases`) | Server-only fields, no client write path |
| Admin privilege | A signed Firebase custom claim, never an email or a document field |
| Outbound email | Cloud Functions, Resend key in Secret Manager |

`firestore.rules` is default-deny, checks ownership on **both** sides of every write, and is covered by an emulator test suite in `../firestore-tests`. App Check attests that requests come from a genuine build.

Release builds block screenshots and screen recording, enforced natively in `onCreate` / `didFinishLaunching` so no frame escapes before Dart starts.

---

## 🛠️ Setup

```bash
cp .env.example .env      # Firebase keys
flutter pub get
flutter run
```

Place `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`.

To regenerate the launcher icon after changing the mark, see the comment above `flutter_launcher_icons` in `pubspec.yaml`, then:

```bash
dart run flutter_launcher_icons
```

---

## 📁 Architecture

```
lib/
├── main.dart                 # Routing, guards, bounded startup
├── firebase_options.dart
├── core/
│   ├── constants/            # Content libraries, professions, config
│   └── theme/                # Dark violet design tokens
├── models/                   # Firestore document shapes
├── services/                 # One service per collection
├── providers/                # Auth & journal state
├── widgets/                  # Shared UI
└── screens/                  # Feature screens
```

Startup awaits Firebase with a 15-second bound and nothing else; App Check and notifications initialise **behind** the first frame, because both can hang and a hung app is indistinguishable from a crashed one.
