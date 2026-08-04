#!/bin/bash
# =============================================================
# Brahma Journal — Firebase Setup Script
# Run this script to complete Firebase setup for Flutter app
# =============================================================

echo "🕉️  Brahma Journal — Firebase Flutter Setup"
echo "============================================="
echo ""

# Set paths
export PATH="$HOME/Documents/flutter/bin:$PATH:$HOME/.pub-cache/bin"

# Step 1: Check tools
echo "✅ Step 1: Checking tools..."
flutter --version | head -1
firebase --version
flutterfire --version
echo ""

# Step 2: Firebase Login (will open browser)
echo "🔐 Step 2: Firebase Login"
echo "   A browser will open — login with your Google account"
echo "   (same account used for Firebase Console)"
echo ""
firebase login

echo ""
echo "✅ Firebase login done!"
echo ""

# Step 3: FlutterFire Configure
echo "⚙️  Step 3: Running FlutterFire Configure..."
echo "   Project: brahma-journal-nhdat"
echo "   Platforms: android, ios"
echo ""

cd "$(dirname "$0")"
flutterfire configure \
  --project=brahma-journal-nhdat \
  --platforms=android,ios \
  --android-package-name=com.brahma.brahmaApp \
  --ios-bundle-id=com.brahma.brahmaApp \
  --out=lib/firebase_options.dart \
  --yes

echo ""
echo "🎉 Firebase setup complete!"
echo "   firebase_options.dart has been updated with Android & iOS App IDs"
echo ""
echo "🚀 Now run the app:"
echo "   flutter run"
