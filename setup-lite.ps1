# Day 19 lightweight setup - PowerShell version
# Run from PowerShell (NOT Git Bash):
#   .\setup-lite.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

Write-Host "[lite] Day 19 lightweight setup" -ForegroundColor Cyan
Write-Host "[lite] Stack: fastembed + qdrant-client[memory] + rank-bm25 + feast(sqlite) + FastAPI"
Write-Host ""

# ── 1. Find Python ─────────────────────────────────────────────────────────
$PY_CMD = $null

# Try py launcher first (Windows Python, not msys2)
try {
    $pyOut = py -3 -c "import sys; print(sys.executable)" 2>$null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $pyOut)) {
        $PY_CMD = $pyOut
        $pyVer = py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        Write-Host "[lite] Windows Python: $PY_CMD ($pyVer)" -ForegroundColor Green
    }
} catch { }

# Fallback: find Python.exe in common locations
if (-not $PY_CMD) {
    $searchPaths = @(
        "C:\Python313\python.exe",
        "C:\Python312\python.exe",
        "C:\Python311\python.exe",
        "C:\Python310\python.exe",
        "C:\Program Files\Python313\python.exe",
        "C:\Program Files\Python312\python.exe",
        "C:\Program Files\Python311\python.exe",
        "C:\Program Files\Python310\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python313\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python310\python.exe"
    )
    foreach ($p in $searchPaths) {
        if (Test-Path $p) {
            $PY_CMD = $p
            $pyVer = & $p -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
            Write-Host "[lite] Found Python: $PY_CMD ($pyVer)" -ForegroundColor Green
            break
        }
    }
}

if (-not $PY_CMD) {
    Write-Host "[lite] ERROR: Python not found. Install Python 3.10+ from python.org" -ForegroundColor Red
    exit 1
}

# ── 2. Create venv ────────────────────────────────────────────────────────
$VENV_PATH = Join-Path $ProjectRoot ".venv"

if (-not (Test-Path "$VENV_PATH\Scripts\Activate.ps1")) {
    Write-Host "[lite] Creating venv with $PY_CMD" -ForegroundColor Cyan
    Remove-Item $VENV_PATH -Recurse -Force -ErrorAction SilentlyContinue
    & $PY_CMD -m venv $VENV_PATH
    if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
} else {
    Write-Host "[lite] venv already exists" -ForegroundColor Cyan
}

# Activate venv
Write-Host "[lite] Activating venv..." -ForegroundColor Cyan
& "$VENV_PATH\Scripts\Activate.ps1"

# Verify activation
$venvPy = & python -c "import sys; print(sys.executable)"
$venvVer = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
Write-Host "[lite] venv Python $venvVer" -ForegroundColor Green

# ── 3. Install deps ────────────────────────────────────────────────────────
$needDill = & python -c "import sys; print(1 if sys.version_info >= (3, 14) else 0)"

if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "[lite] Installing deps with uv..." -ForegroundColor Cyan
    if ($needDill -eq "1") {
        uv pip install --overrides overrides-py314.txt -r requirements.txt
    } else {
        uv pip install -r requirements.txt
    }
} else {
    Write-Host "[lite] Installing deps with pip..." -ForegroundColor Cyan
    python -m pip install -q -U pip
    python -m pip install -q -r requirements.txt
    if ($needDill -eq "1") {
        python -m pip install -q --upgrade "dill>=0.4,<1.0"
    }
}

# ── 4. Convert Jupytext notebooks ─────────────────────────────────────────
Write-Host "[lite] Converting notebooks..." -ForegroundColor Cyan
python -m jupytext --to notebook --update notebooks/[0-9]*.py 2>$null
if ($LASTEXITCODE -ne 0) {
    python -m jupytext --to notebook notebooks/[0-9]*.py
}

# ── 5. .env scaffold ─────────────────────────────────────────────────────
$envFile = Join-Path $ProjectRoot ".env"
$envExample = Join-Path $ProjectRoot ".env.example"
if (-not (Test-Path $envFile)) {
    Copy-Item $envExample $envFile
    Write-Host "[lite] Created .env from .env.example" -ForegroundColor Green
}

# ── 6. Seed corpus + golden set ───────────────────────────────────────────
Write-Host "[lite] Seeding corpus..." -ForegroundColor Cyan
Push-Location $ProjectRoot
python scripts/seed_corpus.py
if ($LASTEXITCODE -ne 0) { throw "seed_corpus.py failed" }

Write-Host "[lite] Seeding advanced-mission data (NB6 + NB8)..." -ForegroundColor Cyan
python scripts/gen_agent_queries.py
python scripts/gen_spend.py
Pop-Location

# ── 7. Smoke test ─────────────────────────────────────────────────────────
Write-Host "[lite] Running smoke test..." -ForegroundColor Cyan
Push-Location $ProjectRoot
python scripts/verify_lite.py
if ($LASTEXITCODE -ne 0) { throw "verify_lite.py failed" }
Pop-Location

Write-Host ""
Write-Host "[lite] Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Activate the venv and start working:"
Write-Host "    .\.venv\Scripts\Activate.ps1"
Write-Host "    make api        # FastAPI on :8000"
Write-Host "    make lab        # Jupyter on :8888"
Write-Host "    make benchmark  # Precision@10 + latency"
Write-Host ""
Write-Host "Tip: read VIBE-CODING.md before starting NB1"
