"""Generate synthetic spend data for on-demand feature demo (NB8)."""
from pathlib import Path
import polars as pl
from datetime import datetime, timedelta, timezone

NOW = datetime.now(timezone.utc).replace(microsecond=0)
DATA_DIR = Path(__file__).resolve().parent.parent / "app" / "feast_repo_ondemand" / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

# 10 users x 20 transactions
n_users = 10
n_txns = 20
rows = []
for u in range(n_users):
    uid = f"u_{u:03d}"
    for t in range(n_txns):
        rows.append({
            "user_id": uid,
            "transaction_id": f"txn_{uid}_{t:03d}",
            "amount_usd": round(10.0 + (u * 7 + t * 3) % 200, 2),
            "merchant_category": ["food", "tech", "travel", "retail"][(u + t) % 4],
            "event_timestamp": NOW - timedelta(hours=(n_txns - t) * 3 + u * 10),
        })

df = pl.DataFrame(rows)
df.write_parquet(DATA_DIR / "transactions.parquet")
print(f"Wrote {len(df)} transactions to {DATA_DIR / 'transactions.parquet'}")
