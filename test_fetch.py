# YAC fonunun son 1 yıllık günlük fiyatlarını (date, code, price) TEFAS'tan çeker
# ve tarihi YYYY-MM-DD metni olarak tefas.db içindeki test_price tablosuna yazar.

import sqlite3
from datetime import date, timedelta

from tefas import Crawler

end = date.today()
start = end - timedelta(days=365)

df = Crawler().fetch(
    start=start.isoformat(),
    end=end.isoformat(),
    name="YAC",
    columns=["date", "code", "price"],
)

df["date"] = df["date"].astype(str).str[:10]
df = df.sort_values("date")

with sqlite3.connect("tefas.db") as conn:
    df.to_sql("test_price", conn, if_exists="replace", index=False)

print(f"{len(df)} satır yazıldı ({df['date'].min()} - {df['date'].max()})")
print(df.head())
print(df.tail())
