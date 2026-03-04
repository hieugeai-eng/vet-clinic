@echo off
REM =============================================
REM PetClinic - Production Build Script
REM =============================================
REM Builds Windows release with:
REM   - Compile-time secrets (no .env file shipped)
REM   - Code obfuscation (harder to reverse engineer)
REM   - Split debug info (for crash reports)

echo Building PetClinic for Windows (production)...
echo.

if not exist ".env.local" (
    echo ERROR: .env.local not found!
    echo Create .env.local with SUPABASE_URL, SUPABASE_ANON_KEY, CLINIC_ID
    exit /b 1
)

flutter build windows ^
    --release ^
    --dart-define-from-file=.env.local ^
    --obfuscate ^
    --split-debug-info=build/debug-info

echo.
echo Build complete! Output: build\windows\x64\runner\Release\
echo Debug symbols: build\debug-info\ (keep for crash reports)
