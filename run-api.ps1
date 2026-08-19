# run-api.ps1 - Start FastAPI for Day 19 lab
# Run from PowerShell (venv must be activated):
#   .\.venv\Scripts\Activate.ps1
#   .\run-api.ps1

Write-Host "Starting FastAPI on http://localhost:8000..." -ForegroundColor Cyan
Write-Host "API docs at http://localhost:8000/docs" -ForegroundColor Cyan
Write-Host ""

& uvicorn app.main:app --reload --port 8000
