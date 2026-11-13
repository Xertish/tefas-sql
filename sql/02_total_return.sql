-- 02_total_return.sql: 5 yýlýn toplamýnda dolar bazýnda hangisi ne kazandýrdý?

-- 1. Dolar fiyatý
-- Ne yapar: Her fon ve GOLD_GRAM fiyatýný ayný günün USDTRY deðerine bölüp dolar fiyatýný bulur. TL 5 yýlda dolar karþýsýnda deðer kaybettiði için TL bazlý yükseliþ yanýltýr.
-- Karar: INNER JOIN. USDTRY'nin olmadýðý gün ortak gün olamaz, sonucu deðiþtirmez; NULL taþýmamak için satýr baþtan düþer.
-- Beklenen: 13.826'dan (15.125 - 1299 USDTRY satýrý) biraz az satýr; dolar fiyatý TL fiyatýndan küçük.
-- Sonuç: 13.796 satýr. 30 satýr fark = USDTRY'si olmayan 3 iþ günü × 10 fon.
SELECT
	fp.asset_code, fp.price, fp.date, fp.price / fp2.price AS usd_price
FROM
	fact_price fp
JOIN fact_price fp2 ON
	fp.date = fp2.date
WHERE
	fp2.asset_code = 'USDTRY'
	AND fp.asset_code <> 'USDTRY';

-- 2. Ortak günler
-- Ne yapar: 11 asset'in (10 fon + GOLD_GRAM) hepsinin dolar fiyatýnýn olduðu günleri bulur. Dolar fiyatý sorgusunu FROM'a koyar, günleri gruplar, 11 satýrý olan günleri tutar.
-- Beklenen: ~1230 satýr (fonlarýn 1257 günü eksi USDTRY'nin ve altýnýn olmadýðý günler), tek kolon date.
-- Sonuç: 1213 satýr. Düþen 44 gün = USDTRY'nin olmadýðý 3 gün + ABD tatili yüzünden altýnýn olmadýðý ~41 gün.
SELECT
	d.date
FROM
	(
	SELECT
		fp.asset_code,
		fp.price,
		fp.date,
		fp.price / fp2.price AS usd_price
	FROM
		fact_price fp
	JOIN fact_price fp2 ON
		fp.date = fp2.date
	WHERE
		fp2.asset_code = 'USDTRY'
		AND fp.asset_code <> 'USDTRY') AS d
GROUP BY
	d.date
HAVING
	COUNT(*) = 11;

-- 3. Ýlk ve son ortak gündeki dolar fiyatý
-- Ne yapar: Her asset'in ilk ve son ortak gündeki dolar fiyatýný bulur; asset_code ile baðlayýp ikisini yan yana koyar. MIN/MAX tarihi common_days'ten alýnýr, böylece 11 asset de ayný iki günden ölçülür.
-- Beklenen: 11 satýr (asset baþýna bir), 3 kolon.
-- Sonuç: 11 satýr.
-- (sorgu)

-- 4. 5 yýllýk toplam dolar getirisi
-- Ne yapar: Son fiyat / ilk fiyat kaç kat büyüdüðünü verir; -1 baþlangýçtaki parayý çýkarýr, kalan kazançtýr; ×100 yüzdeye çevirir. Büyükten küçüðe sýralar.
-- Beklenen: 11 satýr.
-- Sonuç: Hiçbir fon dolar bazýnda altýný geçemedi. GOLD_GRAM %118, en yakýn AFO (altýn fonu) %96. 7 fon artýda, HPT, APT ve AOY ekside.
-- Kontrol: GOLD_GRAM ilk/son dolar fiyatý × 31,1035 = ons fiyatý (~1793 / ~3918 $), piyasa fiyatýyla karþýlaþtýrýldý.
-- (sorgu)