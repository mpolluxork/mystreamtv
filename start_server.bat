@echo off
echo ========================================
echo   MyStreamTV - Starting Server (Windows)
echo ========================================
echo.

cd backend

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo.
echo Starting Uvicorn server on port 8000...
echo Access the app at: http://localhost:8000
echo Admin console at: http://localhost:8000/admin.html
echo.
echo Press Ctrl+C to stop the server
echo.

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
