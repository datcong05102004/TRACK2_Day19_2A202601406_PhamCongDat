#!/usr/bin/env bash
# Lite path: pure Python, in-process Qdrant, SQLite Feast online store.
# No Docker, no GPU, no external services. ~60s on a clean machine.

set -eo pipefail

echo "[lite] Day 19 lightweight setup"
echo "[lite] Stack: fastembed + qdrant-client[memory] + rank-bm25 + feast(sqlite) + FastAPI"
echo

# ── 1. Find a working Python ─────────────────────────────────────────────
# On Windows, Git Bash's msys2 python3 has broken venv support.
# Use the Windows py launcher or find Python.exe directly.
WIN_PY_PATH=""

if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
  # Try Windows py launcher first
  if command -v py >/dev/null 2>&1; then
    # Get the actual executable path from py launcher
    WIN_PY_PATH=$(py -3 -c "import sys; print(sys.executable)" 2>/dev/null)
    if [ -n "$WIN_PY_PATH" ] && [ -f "$WIN_PY_PATH" ]; then
      PY_VER=$(py -3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
      echo "[lite] Windows Python: $WIN_PY_PATH ($PY_VER)"
    else
      WIN_PY_PATH=""
    fi
  fi

  # Fallback: search common Windows Python install paths
  if [ -z "$WIN_PY_PATH" ]; then
    for dir in "/c/Python"* "/c/Program Files/Python"* \
               "/c/Users/${USER:-$(echo ~ | tr -d '~')}/AppData/Local/Programs/Python/Python"*; do
      if [ -f "$dir/python.exe" ]; then
        WIN_PY_PATH="$dir/python.exe"
        PY_VER=$("$WIN_PY_PATH" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        echo "[lite] Found Python at $WIN_PY_PATH ($PY_VER)"
        break
      fi
    done
  fi
fi

# Final fallback: use system python3 (Linux/macOS/WSL)
if [ -z "$WIN_PY_PATH" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "[lite] python3 not found. Install Python 3.10+."; exit 1; }
  WIN_PY_PATH="python3"
  PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  echo "[lite] system python3 is $PY_VER"
fi

# ── 2. venv ─────────────────────────────────────────────────────────────
# uv is preferred (faster + cross-platform). Falls back to python -m venv.
if [ ! -d ".venv" ] || [ ! -f ".venv/pyvenv.cfg" ]; then
  rm -rf .venv
  if command -v uv >/dev/null 2>&1; then
    echo "[lite] Creating venv with uv"
    uv venv .venv --python "$WIN_PY_PATH"
  else
    echo "[lite] Creating venv with $WIN_PY_PATH -m venv"
    "$WIN_PY_PATH" -m venv .venv
  fi
fi

# Activate: Windows uses Scripts/, Unix uses bin/.
if [ -f ".venv/Scripts/activate" ]; then
  # shellcheck source=/dev/null
  source .venv/Scripts/activate
elif [ -f ".venv/bin/activate" ]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
else
  echo "[lite] ERROR: activate script not found in .venv"
  ls -la .venv/
  exit 1
fi

# ── 3. Install deps ─────────────────────────────────────────────────────
# After activation, `python` and `pip` point to the venv.
VENV_PY_VER=$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
NEED_DILL_OVERRIDE=$(python -c 'import sys; print(1 if sys.version_info >= (3, 14) else 0)')
echo "[lite] venv Python $VENV_PY_VER"
if [ "$NEED_DILL_OVERRIDE" = "1" ]; then
  echo "[lite] Python >= 3.14 -> applying dill>=0.4 override (feast's pin is too old; see requirements.txt)"
fi

if command -v uv >/dev/null 2>&1; then
  if [ "$NEED_DILL_OVERRIDE" = "1" ]; then
    uv pip install --overrides overrides-py314.txt -r requirements.txt
  else
    uv pip install -r requirements.txt
  fi
else
  pip install -q -U pip
  pip install -q -r requirements.txt
  if [ "$NEED_DILL_OVERRIDE" = "1" ]; then
    pip install -q --upgrade 'dill>=0.4,<1.0'
  fi
fi

# ── 4. Convert Jupytext sources to .ipynb ───────────────────────────────
# `_setup.py` is a helper module, not a notebook -- converting it produces
# a _setup.ipynb that fails on execute. Only convert numbered notebooks.
jupytext --to notebook --update notebooks/[0-9]*.py 2>/dev/null || jupytext --to notebook notebooks/[0-9]*.py

# ── 5. .env scaffold ────────────────────────────────────────────────────
[ -f .env ] || cp .env.example .env

# ── 6. Seed corpus + golden set ─────────────────────────────────────────
python scripts/seed_corpus.py

# Data for the advanced missions (NB6 compound queries, NB8 spend parquet).
# gen_agent_queries embeds the corpus once to build brute-force ground truth,
# so this adds ~20 s -- worth it: the alternative is students hand-labelling.
echo "  · seeding advanced-mission data (NB6 + NB8)…"
python scripts/gen_agent_queries.py
python scripts/gen_spend.py

# ── 7. Smoke test ───────────────────────────────────────────────────────
python scripts/verify_lite.py

cat <<'EOF'

[lite] Done. Activate the venv and start working:

    source .venv/bin/activate    # Linux / macOS / Git Bash
    make api       # start FastAPI on :8000
    make lab       # open Jupyter on :8888
    make benchmark # Precision@10 + latency table

Tip: read VIBE-CODING.md before starting NB1 — it tells you what to delegate
to your AI assistant and what to think through yourself.
EOF
