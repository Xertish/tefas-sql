-- 01_data_checks.sql
-- Soru: Veriye güvenebilir miyim?
-- Veri: fact_price, 2021-11-04 → 2026-11-03, 15.125 satır


-- 1. Asset bazında başlangıç/bitiş tarihi ve satır sayısı
-- Ne yapar: Asset'lerin başladığı ve bittiği tarihleri alır ve her asset'te
-- kaç satır olduğunu ölçer.
-- Beklenen: 12 satır, bütün asset'lerde aynı MIN/MAX tarih
-- Sonuç: Bütün asset'ler 2021-11-04 → 2026-11-03. Fonlar 1257, USDTRY 1299,
-- GOLD_GRAM 1256 satır.
SELECT
	asset_code,
	MIN(date) AS start_date,
	MAX(date) AS end_date,
	COUNT(*) AS row_count
FROM
	fact_price
GROUP BY
	asset_code;


-- 2. USDTRY'de olup fonlarda olmayan günler (Türkiye resmi tatilleri)
-- Ne yapar: fact_price'taki USDTRY satırlarını tek tek gezer; her satır için
-- fact_price'a tekrar (fp2) bakıp aynı tarihte APT satırı var mı diye sorar.
-- Yoksa o tarihi getirir. Bu günler TEFAS'ın kapalı, döviz piyasasının açık
-- olduğu Türkiye resmi tatilleridir. APT, bütün fonların temsilcisi olarak
-- seçildi (bütün fonlar 1257 satır).
-- Beklenen: bayramlar, 19 Mayıs, 15 Temmuz gibi günler
-- Sonuç: Türkiye resmi tatilleri. Karşılaştırmalarda ortak günler kullanılmalı.
SELECT fp.date
FROM fact_price fp
WHERE fp.asset_code = 'USDTRY'
AND NOT EXISTS (
    SELECT 1
    FROM fact_price fp2
    WHERE fp2.asset_code = 'APT'
      AND fp2.date = fp.date
);


-- 3. Kolon bazında null sayısı
-- Ne yapar: Üç kolonun her birinde kaç null olduğunu bulur. COUNT(*) bütün
-- satırları, COUNT(kolon) sadece null olmayanları sayar; aradaki fark o
-- kolondaki null sayısıdır. Kolon bazında bakıyoruz ki sorun çıkarsa hangi
-- kolonda olduğu hemen görülsün.
-- Beklenen: 1 satır, 3 kolon, hepsi 0
-- Sonuç: 0, 0, 0
SELECT
	COUNT(*) - COUNT(price) AS null_prices,
	COUNT(*) - COUNT(date) AS null_date,
	COUNT(*) - COUNT(asset_code) AS null_ac
FROM
	fact_price;


-- 4. Fiyatı 0 ya da negatif olan satırlar
-- Ne yapar: Fiyatı 0 ya da negatif olan satırları sayar. Null olmasa da
-- bozuk gelmiş fiyatı yakalamak için.
-- Beklenen: 1 satır, 0
-- Sonuç: 0
SELECT COUNT(*) AS non_positive_prices FROM fact_price
WHERE price <= 0;


-- 5. Formatı bozuk tarihler
-- Ne yapar: 'YYYY-MM-DD' 10 karakterdir; uzunluğu 10 olmayan tarihleri sayar.
-- PK '2026-11-03' ile '2026-11-03 00:00:00'ı farklı görür; format bozuksa
-- aynı gün iki satır olarak girebilir.
-- Not: Bu sadece şekle bakar. 2059 gibi bir yıl 1. sorgudaki MAX(date)'te
-- görünürdü; '2026-32-15' gibi olmayan bir gün dim_date yetim kontrolünde
-- yakalanır (4. oturumun ilk sorgusu).
-- Beklenen: 1 satır, 0
-- Sonuç: 0
SELECT COUNT(*) AS invalid_date FROM fact_price
WHERE LENGTH(date) <> 10;


-- 6. Duplicate: aynı (tarih, fon) çifti birden fazla mı?
-- Ne yapar: Satırları (date, asset_code) çiftine göre gruplar; HAVING ile
-- içinde 1'den fazla satır olan grupları getirir. Bu iki kolon PK olduğu için
-- her grupta tek satır olmalı.
-- Beklenen: boş sonuç
-- Sonuç: boş
SELECT date, asset_code FROM fact_price
GROUP BY date, asset_code HAVING COUNT(*) > 1;

-- Hafta sonu kontrolü (sorgusuz): Hafta sonları da olsaydı her fonun yaklaşık
-- 1826 satırı olurdu (5 × 365). Fonlarda 1257 satır var, yılda ~251 gün; yani
-- sadece iş günleri. Cuma fiyatı hafta sonuna kopyalanmamış.


-- 7. Yetim kayıt: fact_price'ta olup dim_asset'te olmayan asset_code
-- Ne yapar: fact_price tablosunu satır satır gezer; her satır için dim_asset'e
-- dönüp bu asset_code'un karşılığı var mı diye bakar. Karşılığı varsa sonuca
-- girmez, yoksa girer. SQLite'ta foreign key kontrolü varsayılan olarak kapalı
-- olduğu için bunu elle kontrol ediyoruz.
-- Beklenen: boş sonuç
-- Sonuç: boş
SELECT
	fp.asset_code, COUNT(*) AS error_count
FROM
	fact_price fp
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		dim_asset dm
	WHERE
		fp.asset_code = dm.asset_code)
GROUP BY fp.asset_code;

-- 8. Yetim tarih
-- Ne yapar: fact_price'taki her satır kendi tarihini dim_date'te arar; karşılığı olmayan tarih, kaç satırı etkilediğiyle birlikte sonuca çıkar.
-- Beklenen: Boş sonuç (0 satır).
-- Sonuç: Boş döndü, yetim tarih yok.
SELECT
	fp.date, COUNT(*) AS error_count
FROM
	fact_price fp
WHERE
	NOT EXISTS (
	SELECT
		1
	FROM
		dim_date dd
	WHERE
		fp.date = dd.date)
GROUP BY fp.date;
