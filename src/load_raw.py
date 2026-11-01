import os, sys, time
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parents[1]))

import pandas as pd
import requests
from dotenv import load_dotenv
from sqlalchemy import create_engine, text, inspect, Text
from sqlalchemy.dialects.postgresql import JSONB

from src.extract.openf1 import get

load_dotenv()
engine = create_engine(os.environ["DATABASE_URL"])

YEARS = [2023, 2024, 2025]          # add 2026 later
OPENF1_ENDPOINTS = ["laps", "stints", "pit", "race_control", "drivers"]
JOLPICA = "https://api.jolpi.ca/ergast/f1"

with engine.begin() as c:
    c.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))
    c.execute(text("""
        CREATE TABLE IF NOT EXISTS raw.load_log (
            source TEXT, endpoint TEXT, key TEXT,
            rows_loaded INT, loaded_at TIMESTAMPTZ DEFAULT now(),
            PRIMARY KEY (source, endpoint, key))"""))


def already_loaded(source, endpoint, key):
    with engine.connect() as c:
        return c.execute(text(
            "SELECT 1 FROM raw.load_log WHERE source=:s AND endpoint=:e AND key=:k"),
            {"s": source, "e": endpoint, "k": str(key)}).first() is not None


def save(df, table, source, endpoint, key):
    """Append a DataFrame to raw.<table> as TEXT/JSONB and record it in the load log."""
    if not df.empty:
        json_cols = [c for c in df.columns
                     if df[c].dropna().map(lambda v: isinstance(v, (list, dict))).any()]
        for c in df.columns:
            if c not in json_cols:
                df[c] = df[c].astype("string")
        dtype = {c: (JSONB if c in json_cols else Text) for c in df.columns}

        insp = inspect(engine)
        if insp.has_table(table, schema="raw"):
            existing = {col["name"] for col in insp.get_columns(table, schema="raw")}
            with engine.begin() as c:
                for col in df.columns:
                    if col not in existing:
                        coltype = "JSONB" if col in json_cols else "TEXT"
                        c.execute(text(f'ALTER TABLE raw.{table} ADD COLUMN "{col}" {coltype}'))

        df.to_sql(table, engine, schema="raw", if_exists="append",
                  index=False, dtype=dtype, method="multi", chunksize=1000)

    with engine.begin() as c:
        c.execute(text("""INSERT INTO raw.load_log (source, endpoint, key, rows_loaded)
                          VALUES (:s,:e,:k,:n) ON CONFLICT DO NOTHING"""),
                  {"s": source, "e": endpoint, "k": str(key), "n": len(df)})


# ---------- OpenF1 ----------
def load_openf1():
    for year in YEARS:
        sessions = get("sessions", year=year, session_name="Race")
        sessions = [s for s in sessions if not s.get("is_cancelled")]
        if not already_loaded("openf1", "sessions", year):
            save(pd.DataFrame(sessions), "sessions", "openf1", "sessions", year)
        for s in sessions:
            key = s["session_key"]
            for ep in OPENF1_ENDPOINTS:
                if already_loaded("openf1", ep, key):
                    continue
                try:
                    rows = get(ep, session_key=key)
                except requests.HTTPError as e:
                    if e.response is not None and e.response.status_code == 404:
                        save(pd.DataFrame(), ep, "openf1", ep, key)
                        print(f"openf1 {year} {s['circuit_short_name']:<14} {ep:<13} NO DATA (404)")
                    else:
                        print(f"  FAILED {ep} {key}: {e}")
                    continue
                except Exception as e:
                    print(f"  FAILED {ep} {key}: {e}")
                    continue
                df = pd.DataFrame(rows)
                save(df, ep, "openf1", ep, key)
                print(f"openf1 {year} {s['circuit_short_name']:<14} {ep:<13} {len(df):>5} rows")


# ---------- Jolpica ----------
def jolpica_pages(path):
    offset, limit = 0, 100
    while True:
        r = requests.get(f"{JOLPICA}/{path}", params={"limit": limit, "offset": offset}, timeout=30)
        r.raise_for_status()
        data = r.json()["MRData"]
        yield data
        offset += limit
        time.sleep(1)
        if offset >= int(data["total"]):
            break


def load_jolpica():
    for year in YEARS:
        for endpoint, list_key in [("results", "Results"), ("qualifying", "QualifyingResults")]:
            if already_loaded("jolpica", endpoint, year):
                continue
            rows = []
            for page in jolpica_pages(f"{year}/{endpoint}.json"):
                for race in page["RaceTable"]["Races"]:
                    for res in race[list_key]:
                        row = {"season": int(race["season"]), "round": int(race["round"]),
                               "race_name": race["raceName"], "race_date": race["date"],
                               "circuit_id": race["Circuit"]["circuitId"]}
                        row.update(pd.json_normalize(res, sep="_").iloc[0].to_dict())
                        rows.append(row)
            save(pd.DataFrame(rows), f"jolpica_{endpoint}", "jolpica", endpoint, year)
            print(f"jolpica {year} {endpoint:<11} {len(rows):>5} rows")


if __name__ == "__main__":
    load_openf1()
    load_jolpica()
    print("Done.")