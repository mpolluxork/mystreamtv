Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyStreamTV - Starting Server (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location backend

Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1

Write-Host ""
Write-Host "Starting Uvicorn server on port 8000..." -ForegroundColor Green
Write-Host "Access the app at: http://localhost:8000" -ForegroundColor White
Write-Host "Admin console at: http://localhost:8000/admin.html" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
