# Development Setup

This repository contains a Flutter mobile app in `frontend` and an optional
FastAPI backend in `backend`.

## Prerequisites

Install the following:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (includes Dart)
- Android Studio with the Android SDK and an Android SDK platform installed
- A physical Android device with **Developer options** and **USB debugging**
  enabled, or an Android emulator
- Python 3.11+ only when running the backend locally

Verify the Flutter/Android installation:

```powershell
flutter doctor
flutter devices
```

Accept any outstanding Android SDK licenses if Flutter requests it:

```powershell
flutter doctor --android-licenses
```

## Run the Flutter App

1. Connect the Android device, approve its USB-debugging prompt, or start an
   emulator from Android Studio.
2. From the repository root, install packages and launch the app:

```powershell
cd frontend
flutter pub get
flutter run
```

If more than one device is available, copy an ID from `flutter devices` and
run:

```powershell
flutter run -d <device-id>
```

The app is configured to use the deployed API by default, so a local backend
is not required for normal mobile development.

While `flutter run` is active, press `r` for hot reload or `R` for a hot
restart.

## Optional: Run the Backend Locally

1. Create and activate a virtual environment:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Create `backend\.env` with at least a PostgreSQL connection string:

```dotenv
DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<database>
SECRET_KEY=<secure-development-secret>
GITHUB_TOKEN=<github-token-with-model-access>
```

`GITHUB_TOKEN` is required only for the AI chat features.

3. Start the API:

```powershell
uvicorn main:app --reload
```

The local API will be available at `http://localhost:8000` and interactive
documentation at `http://localhost:8000/docs`.

To make a physical Android device use a local backend, use your computer's LAN
IP address rather than `localhost` in the frontend API configuration.
