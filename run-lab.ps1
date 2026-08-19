# run-lab.ps1 - Start Jupyter Lab for Day 19 lab
# Run from PowerShell (venv must be activated):
#   .\.venv\Scripts\Activate.ps1
#   .\run-lab.ps1

$ProjectRoot = $PSScriptRoot

Write-Host "Starting Jupyter Lab..." -ForegroundColor Cyan

# Convert notebooks if needed
& jupytext --to notebook --update notebooks/[0-9]*.py 2>$null

# Start Jupyter Lab
& jupyter lab --notebook-dir=notebooks --ServerApp.token= --no-browser
