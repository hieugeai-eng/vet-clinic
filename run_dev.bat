@echo off
REM =============================================
REM PetClinic - Development Run Script
REM =============================================
REM Runs the app with secrets from .env.local (compile-time)

echo Starting PetClinic in development mode...
flutter run -d windows --dart-define-from-file=.env.local
