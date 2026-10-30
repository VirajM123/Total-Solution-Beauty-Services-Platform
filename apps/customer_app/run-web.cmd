@echo off
setlocal
cd /d "%~dp0"
echo Open http://localhost:58408 in Chrome after Flutter prints the serving URL.
echo Press Ctrl+C here to stop the app. Restart this command after code changes.
call flutter run -d web-server --web-hostname=localhost --web-port=58408 %*
exit /b %errorlevel%
