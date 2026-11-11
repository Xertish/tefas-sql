# tefas-sql

## Veriye güvenebilir miyim?
Fon fiyatları TEFAS'tan (tefas-crawler), USDTRY ve ons altın (GC=F) Yahoo Finance'ten (yfinance) çekildi.
 Gram altın, ons fiyatı ve USDTRY'den hesaplanan yaklaşık bir değerdir.
 `sql/01_data_checks.sql` dosyasındaki 7 kontrolde eksik değer, tekrar eden kayıt, bozuk tarih ya da geçersiz fiyat çıkmadı.
 Türkiye ve ABD tatilleri yüzünden asset'lerin işlem günleri birbirini tutmuyor, bu yüzden karşılaştırmalar sadece ortak günler üzerinden yapılacak.