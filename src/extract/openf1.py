import time
import requests

BASE = "https://api.openf1.org/v1"

def get(path, retries=5, pause=0.4, **params):
    """GET an OpenF1 endpoint with backoff on rate limits."""
    for attempt in range(retries):
        r = requests.get(f"{BASE}/{path}", params=params, timeout=30)
        if r.status_code == 429:
            time.sleep(2 ** attempt)
            continue
        r.raise_for_status()
        time.sleep(pause)          # be polite between calls
        return r.json()
    raise RuntimeError(f"OpenF1 {path}: gave up after {retries} retries")