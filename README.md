# Nutrition Coach

Flutter nutrition tracker with Arabic/English UI, local SQLite storage, date-aware meal logging/editing, macro targets, progress and weight tracking, coaching tips, optional Gemini meal/photo estimation, AI-generated 7-day meal plans, coach chat, and clipboard backup/restore.

## GitHub build
Push to `main`. GitHub Actions generates the Android project, installs packages, runs `flutter analyze` and `flutter test`, builds the release APK, and uploads `nutrition-coach-apk` as an artifact. Download it from **Actions → latest successful run → Artifacts**.

## Enable AI
Install the app and add a Gemini API key in Settings. Create the key in Google AI Studio. It is saved locally on the device; never commit it to GitHub. AI requires internet and is subject to provider model availability and quotas. For public releases, use a backend proxy because mobile API keys cannot be kept fully secret.

## Local build
Run `flutter create --platforms=android --project-name nutrition_coach .`, then `flutter pub get`, `flutter analyze`, and `flutter build apk --release`.

Nutrition estimates are approximate. The app is for adult wellness, not medical care.
