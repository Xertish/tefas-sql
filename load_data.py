# 10 TEFAS fonunun son 5 yıllık günlük fiyatlarını (TEFAS), USD/TRY kurunu ve
# gram altın TL fiyatını (yfinance) çekip tefas.db içine yıldız şema olarak yükler:
# dim_asset, dim_date, fact_price. Tekrar çalıştırılabilir; test_price'a dokunmaz.

import sqlite3
import sys
import time
import warnings
from datetime import date, timedelta

import pandas as pd
import yfinance as yf
from tefas import Crawler

DB = "tefas.db"
YEARS = 5
CHUNK_DAYS = 90  # TEFAS uzun tarih aralığını tek istekte vermiyor
RETRIES = 3

warnings.filterwarnings("ignore")
sys.stdout.reconfigure(encoding="utf-8")

FUNDS = {
    "AKU": "Hisse",
    "ANL": "Para Piyasası",
    "AFO": "Altın",
    "AOY": "Yabancı Hisse",
    "GBC": "Yabancı Hisse",
    "TFF": "Yabancı Hisse",
    "APT": "Borçlanma",
    "HPT": "Borçlanma",
    "AGC": "Değişken",
    "GZG": "Değişken",
}

end = date.today()
start = end - timedelta(days=365 * YEARS)


def fetch_fund(code):
    """Fonu 90 günlük parçalar halinde çeker. Hata veren parçayı birkaç kez dener,
    yine gelmezse atlar. (veri, gelmeyen parçaların listesi) döndürür."""
    crawler = Crawler()
    parts, failed = [], []
    s = start
    while s <= end:
        e = min(s + timedelta(days=CHUNK_DAYS - 1), end)
        for attempt in range(RETRIES):
            try:
                df = crawler.fetch(start=s.isoformat(), end=e.isoformat(), name=code,
                                   columns=["date", "code", "title", "price"])
                if df is not None and not df.empty:
                    parts.append(df)
                break
            except Exception:
                time.sleep(2 * (attempt + 1))
        else:
            failed.append(f"{s} - {e}")
        s = e + timedelta(days=1)
    if not parts:
        return pd.DataFrame(columns=["date", "code", "title", "price"]), failed
    df = pd.concat(parts)
    df["date"] = df["date"].astype(str).str[:10]
    df = df[df["price"] > 0]
    return df.drop_duplicates(subset=["date"]).sort_values("date"), failed


def fetch_yahoo(ticker):
    """Yahoo Finance'tan günlük kapanış serisini (index: YYYY-MM-DD) döndürür."""
    df = yf.download(ticker, start=start.isoformat(), end=(end + timedelta(days=1)).isoformat(),
                     progress=False, auto_adjust=False)
    if df.empty:
        return pd.Series(dtype=float)
    close = df["Close"]
    if isinstance(close, pd.DataFrame):
        close = close.iloc[:, 0]
    close = close.dropna()
    close.index = pd.to_datetime(close.index).strftime("%Y-%m-%d")
    return close


# --- 1. Veriyi çek ---
assets = []   # (asset_code, asset_name, asset_type, category)
prices = []   # (date, asset_code, price)
notes = []

for code, category in FUNDS.items():
    df, failed = fetch_fund(code)
    name = df["title"].iloc[-1] if not df.empty else code
    assets.append((code, name, "FUND", category))
    prices += [(d, code, float(p)) for d, p in zip(df["date"], df["price"])]
    if df.empty:
        notes.append(f"{code}: hiç veri gelmedi")
    elif df["date"].min() > (start + timedelta(days=10)).isoformat():
        notes.append(f"{code}: 5 yıldan kısa, veri {df['date'].min()} tarihinden başlıyor")
    if failed and not df.empty:
        notes.append(f"{code}: şu aralıklar TEFAS'tan gelmedi: {', '.join(failed)}")

usdtry = fetch_yahoo("TRY=X")
gold_usd = fetch_yahoo("GC=F")
gold_gram = (gold_usd * usdtry / 31.1035).dropna()  # sadece iki serinin ortak günleri

assets.append(("USDTRY", "ABD Doları / Türk Lirası", "FX", "FX"))
assets.append(("GOLD_GRAM", "Gram Altın (TL)", "GOLD", "GOLD"))
prices += [(d, "USDTRY", float(p)) for d, p in usdtry.items()]
prices += [(d, "GOLD_GRAM", float(p)) for d, p in gold_gram.items()]
if usdtry.empty:
    notes.append("USDTRY: hiç veri gelmedi")
if gold_gram.empty:
    notes.append("GOLD_GRAM: hiç veri gelmedi")

# --- 2. Tabloları oluştur ve yükle ---
with sqlite3.connect(DB) as conn:
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS dim_asset (
            asset_code TEXT PRIMARY KEY,
            asset_name TEXT,
            asset_type TEXT,
            category   TEXT
        );
        CREATE TABLE IF NOT EXISTS dim_date (
            date        TEXT PRIMARY KEY,
            year        INTEGER,
            quarter     INTEGER,
            month       INTEGER,
            day_of_week INTEGER
        );
        CREATE TABLE IF NOT EXISTS fact_price (
            date       TEXT,
            asset_code TEXT,
            price      REAL,
            PRIMARY KEY (date, asset_code)
        );
    """)

    conn.executemany("INSERT OR REPLACE INTO dim_asset VALUES (?, ?, ?, ?)", assets)
    conn.executemany("INSERT OR REPLACE INTO fact_price VALUES (?, ?, ?)", prices)

    # dim_date: fact_price'taki ilk tarihten son tarihe kadar her takvim günü
    first, last = conn.execute("SELECT MIN(date), MAX(date) FROM fact_price").fetchone()
    if first:
        days = pd.date_range(first, last, freq="D")
        rows = [(d.strftime("%Y-%m-%d"), d.year, d.quarter, d.month, d.isoweekday())
                for d in days]  # day_of_week: 1=Pazartesi ... 7=Pazar
        conn.executemany("INSERT OR REPLACE INTO dim_date VALUES (?, ?, ?, ?, ?)", rows)

# --- 3. Rapor ---
counts = pd.Series([p[1] for p in prices]).value_counts()
for code, *_ in assets:
    print(f"{code}: {counts.get(code, 0)}")
if notes:
    print("\nNot:")
    for n in notes:
        print(f"- {n}")
