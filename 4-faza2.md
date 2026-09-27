# Faza 2.1 – 2.4 — JOIN, Aqreqasiya, Subquery, CTE (Ətraflı Qeydlər)

> Bu fayl, Faza 2.1 (JOIN-lər), 2.2 (GROUP BY/HAVING/FILTER), 2.3 (subquery-lər) və 2.4 (CTE/`WITH`) üzrə keçdiyimiz hər şeyin ətraflı qeydidir. 2.5 (window funksiyaları, `LAG`-a qədər) hələ bu fayla daxil deyil. Unutsan, buraya qayıt.

---

## 2.1 — JOIN-lər

### `INNER JOIN` — ən sadəsi

```sql
SELECT o.id, c.full_name, o.status
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id;
```
Yalnız **hər iki tərəfdə uyğunluğu olan** sətirləri gətirir. `o`, `c` — cədvəl alias-larıdır (hər iki cədvəldə `id` olduğu üçün qarışıqlığın qarşısını alır). `ON c.id = o.customer_id` — birləşdirmə şərtidir.

**Sadə `JOIN` (heç bir söz əlavə olmadan) elə `INNER JOIN`-in qısa yazılışıdır** — tam eynidir.

### `LEFT JOIN` — sol tərəfin hamısını saxlayır

```sql
SELECT c.full_name, o.id AS order_id
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id;
```
**Sol tərəfdəki (yazılış sırasında birinci) cədvəlin BÜTÜN sətirləri** saxlanılır — sağ tərəfdə uyğunluq olsun-olmasın. Uyğunluq yoxdursa, sağ tərəfin sütunları `NULL` olur.

**Anti-join pattern** — "uyğunluğu olmayanları tapmaq":
```sql
SELECT c.full_name FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
```
Bu, **heç sifariş verməmiş** müştəriləri tapır (5000 müştəri, 20000 sifariş təsadüfi paylananda, statistik olaraq ~90 müştəri heç bir sifariş almaya bilər — `e^(-20000/5000) ≈ 1.8%`).

### Digər JOIN növləri (qısa)
- **`RIGHT JOIN`** — `LEFT JOIN`-in əksi, nadir işlədilir (cədvəl sırasını dəyişib `LEFT JOIN` yazmaq adətən daha oxunaqlıdır).
- **`FULL OUTER JOIN`** — hər iki tərəfin bütün sətirləri, uyğun olmayan yerlər `NULL`.
- **`CROSS JOIN`** — Dekart hasili: sol tərəfin **hər** sətri, sağ tərəfin **hər** sətri ilə birləşir, şərtsiz (`N × M` sətir). Misal: 2 rəng × 3 ölçü = 6 kombinasiya.
- **`CROSS JOIN LATERAL`** — bizim `order_items` seed datasında işlətmişik. Adi `CROSS JOIN`-dən fərqi: sağdakı alt-sorğu **sol tərəfin hər sətri üçün ayrıca, yenidən** icra olunur. Bunsuz (`LATERAL` olmadan), `ORDER BY random() LIMIT 3` bir dəfə icra olunub, **eyni 3 məhsul bütün sifarişlərə** bağlanardı — `LATERAL` hər sifarişin öz təsadüfi 3 məhsulunu almasını təmin edir.

### ⚠️ Vacib tələ — `ON` vs `WHERE` `LEFT JOIN`-də

```sql
-- Bu, LEFT JOIN-i praktiki olaraq INNER JOIN-ə çevirir (çox vaxt istənməyən nəticə):
SELECT c.full_name, o.status FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.status = 'paid';
```

**Niyə:** `LEFT JOIN` əvvəlcə **bütün** müştəriləri saxlayır (sifarişi olmayan üçün `o.status = NULL`). Sonra `WHERE o.status = 'paid'` **hər sətrə tətbiq olunur**. Sifarişi olmayan (və ya `paid` olmayan) müştəri üçün: `NULL = 'paid'` → **`NULL`** (üç-qiymətli məntiq, 1.2-dən). `WHERE` yalnız `true`-nu saxlayır, `NULL`-u yox → o müştəri **atılır**. Nəticədə `LEFT JOIN`-in "hamısını saxla" vədi **səssizcə pozulur**.

**Konkret misal (3 müştəri):**
| Müştəri | Vəziyyət | `LEFT JOIN` sonrası `o.status` | `WHERE o.status='paid'`-dən sonra |
|---|---|---|---|
| A | `paid` sifarişi var | `'paid'` | ✅ qalır |
| B | sifarişi var, statusu `pending` | `'pending'` | ❌ atılır (`'pending'='paid'` → false) |
| C | heç sifarişi yoxdur | `NULL` | ❌ atılır (`NULL='paid'` → NULL) |

**Bu "səhv" deyil — niyyətdən asılıdır:**
- **"Yalnız `paid` sifarişləri görmək istəyirəm, qalanı maraqlandırmır"** → `WHERE` düzgündür (əslində `INNER JOIN` da kifayətdir, `LEFT JOIN` yazmağa ehtiyac yoxdur).
- **"Bütün müştəriləri görmək istəyirəm, kimin `paid` sifarişi var, kimin yox"** → filtri `ON`-a köçür:
```sql
SELECT c.full_name, o.status FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id AND o.status = 'paid';
```
İndi A, B, C **hamısı qalır** — B və C ikisi də `o.status=NULL` göstərir ("mənim `paid` sifarişim yoxdur" mənasında), heç kim atılmır.

**Ümumi qayda:** `INNER JOIN`-də `ON` vs `WHERE` fərq etmir (heç bir "qorunan" sətir yoxdur ki, itirilsin). Fərq yalnız `LEFT/RIGHT/FULL JOIN`-in **qorunan tərəfinə aid sütuna** filtr qoyanda önəmlidir.

---

## 2.2 — Aqreqasiya: `GROUP BY`, `HAVING`, `FILTER`

### Əsas qayda: aqreqat funksiya + adi sütun qarışığı

```sql
SELECT name, price FROM products LIMIT 5;        -- ✅ OK, aqreqat yoxdur, GROUP BY lazım deyil
SELECT avg(price) FROM products;                  -- ✅ OK, yalnız aqreqat var
SELECT category_id, avg(price) FROM products;     -- ❌ XƏTA, qarışıq, GROUP BY yoxdur
SELECT category_id, avg(price) FROM products
GROUP BY category_id;                              -- ✅ OK, qarışıqlıq GROUP BY ilə həll olunub
```
**Niyə xəta verir:** `avg(price)` bütün sətirləri **bir** dəyərə yığır, amma `category_id` (adi sütun) hər sətirdə **fərqli ola bilər** — PostgreSQL "hansı `category_id`-ni göstərim?" sualına cavab tapa bilmir. `GROUP BY category_id` bunu həll edir: "hər fərqli `category_id` üçün ayrı nəticə sətri düzəlt" deyir, indi hər qrupda `category_id` **tək dəyərdir**, göstərilə bilər.

Eyni qayda: `GROUP BY category_id` yazıb `SELECT`-də `id, name`-i də (aqreqat olmadan) yazmaq **olmaz** — çünki bir kateqoriyadakı bir neçə məhsulun **fərqli** `id`/`name`-ləri var, hansını göstərəcəyi qeyri-müəyyəndir.

### `count()` formaları

- **`count(*)`** — bütün sətirləri sayır (NULL daxil).
- **`count(sütun)`** — yalnız o sütun `NULL` **olmayan** sətirləri sayır.
- **`count(DISTINCT sütun)`** — yalnız **fərqli** dəyərləri sayır (təkrarsız).

### `HAVING` — qrupları filtrləmək

```sql
SELECT customer_id, count(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING count(*) > 5;
```
**Fərq `WHERE` ilə:** `WHERE` sətirləri (`GROUP BY`-dan **əvvəl**) filtrləyir, `HAVING` qrupları (`GROUP BY`-dan **sonra**) filtrləyir. İcra ardıcıllığı: `FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY`.

**Vacib:** `HAVING`-də `SELECT`-də verilən **alias** işlətmək olmaz (`HAVING order_count > 5` — xəta verir), çünki `HAVING` `SELECT`-dən **əvvəl** icra olunur — məhz 1.1-dəki `WHERE price_with_vat` nümunəsinin eynisi. Ona görə `HAVING count(*) > 5` (aqreqat funksiyanın özü) yazılmalıdır, alias yox.

### `FILTER` — şərtli aqreqasiya

```sql
SELECT
    count(*)                                     AS total,
    count(*) FILTER (WHERE status = 'paid')      AS paid,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled
FROM orders;
```
`count(*) FILTER (WHERE şərt)` — "yalnız bu şərtə uyğun sətirləri say" — eyni sorğuda, **bir keçişdə**, fərqli şərtlərə görə fərqli sayımlar. `CASE`-in qısa, oxunaqlı formasıdır (`count(CASE WHEN status='paid' THEN 1 END)`-in ekvivalenti).

### `ROLLUP` (qısa, nadir işlədilir)

Adi `GROUP BY`-ın verdiyi nəticələrin sonuna, əlavə "ümumi cəm" sətri(ləri) qoyur (`country=NULL` kimi görünən sətir — "hamısı" mənasında). Çox sütunla (`ROLLUP(a,b,c)`) hər sütun üçün ayrı-ayrı ara-cəm səviyyəsi yaranır, sıra əhəmiyyətlidir. Dərinləşdirməyə hələlik ehtiyac yoxdur.

---

## 2.3 — Subquery-lər (alt-sorğular)

### Skalyar subquery (bir dəyər qaytarır)

```sql
SELECT name, price,
       (SELECT avg(price) FROM products) AS avg_price
FROM products;
```
Mötərizə içində **ayrı bir SELECT**, nəticəsi **bir dəyərdir** (bütün cədvəlin ortalaması), hər sətirə **eyni** şəkildə "yapışdırılır" (hər sətirdə eyni `avg_price` görünür).

### `EXISTS` / `NOT EXISTS`

```sql
SELECT c.* FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```
`EXISTS` — "bu alt-sorğu heç olmasa **bir** sətir qaytarırmı?" sualına `true`/`false` cavabı verir (nəticənin məzmunu ilə maraqlanmır). `SELECT 1` — konkret dəyər əhəmiyyətsizdir. `NOT EXISTS` — əksi, "heç sifarişi olmayan müştəriləri tap" (`LEFT JOIN ... WHERE o.id IS NULL` anti-join pattern-inin alternativ üsulu, eyni nəticəni verir).

### Korrelyasiyalı (correlated) subquery

```sql
SELECT p.name, p.price
FROM products p
WHERE p.price > (
    SELECT avg(price) FROM products p2 WHERE p2.category_id = p.category_id
);
```
**Məqsəd:** "hər kateqoriyada, öz kateqoriyasının ortalamasından baha olan məhsulları tap" — bütün cədvəlin ümumi ortalaması **yox**.

**Fərq skalyar subquery-dən:** bu alt-sorğu **xarici sorğunun sətrinə istinad edir** (`p2.category_id = p.category_id`, `p` — xarici sorğudandır). Ona görə alt-sorğu **hər sətir üçün ayrıca, fərqli nəticə ilə** yenidən hesablanır (Electronics məhsulu üçün — Electronics-in ortalaması; Books məhsulu üçün — Books-un ortalaması). Skalyar subquery isə (yuxarıdakı `avg_price` nümunəsi) **hər sətir üçün eyni** nəticəni verirdi, çünki heç bir xarici sətrə bağlı deyildi.

### Tələ — `NOT IN` və `NULL` (xatırlatma, 1.2-dən)

`NOT IN (siyahı)` içində bir `NULL` olsa, bütün nəticə səssizcə boşalır. Bunun yerinə **`NOT EXISTS`** istifadə et.

---

## 2.4 — CTE (`WITH`)

### Sintaksis qəlibi

```sql
WITH <ad> AS (
    <tam bir SELECT sorğusu>
)
<başqa bir SELECT, <ad>-ı əsl cədvəl kimi istifadə edərək>
```

`WITH <ad> AS (...)` — mötərizədəki sorğunun nəticəsini, **müvəqqəti, adlandırılmış** bir "cədvəl" kimi yaddaşda saxlayır. Sonra əsas sorğuda ona **əsl cədvəlmiş kimi** istinad edə bilirsən (`JOIN` daxil).

### Tam nümunə — addım-addım qurulma

**Məqsəd:** ən yüksək məbləğli 5 sifarişi tapmaq (`orders`-da "ümumi məbləğ" sütunu yoxdur, `order_items`-dən hesablanmalıdır).

**Addım 1 (tələb → SQL uyğunluğu):** "**hər sifariş üçün**, **məbləğin cəmini** tap" → `GROUP BY order_id` + `sum(quantity * unit_price)`:
```sql
SELECT order_id, sum(quantity * unit_price) AS total
FROM order_items
GROUP BY order_id;
```
Bu, **tək başına, tam bir sorğudur** — `WITH` hələ lazım deyil.

**Addım 2 — CTE-yə "sarmaq":** bu nəticəni `orders`-a `JOIN` edib statusu da görmək, sıralamaq, ilk 5-i almaq istədiyimiz üçün, `WITH` içinə qoyuruq:
```sql
WITH order_totals AS (
    SELECT order_id, sum(quantity * unit_price) AS total
    FROM order_items
    GROUP BY order_id
)
SELECT o.id, ot.total, o.status
FROM order_totals ot
JOIN orders o ON o.id = ot.order_id
ORDER BY ot.total DESC
LIMIT 5;
```

**Diqqət — tez-tez edilən səhv:** `ORDER BY ot.order_id` yazmaq (bu, sadəcə ID-yə görə sıralayır, **məbləğə görə yox**). Məqsəd "ən yüksək məbləğli" olduğu üçün **`ORDER BY ot.total DESC`** olmalıdır.

**Requirement → SQL uyğunluq qaydası (ümumi, yadda saxla):** "hər X üçün, Y-nin cəmini/sayını/ortalamasını tap" eşidəndə → `GROUP BY X` + `sum/count/avg(Y)` düşün.

### Subquery vs CTE — eyni məqsəd, iki forma

```sql
-- Subquery forması:
SELECT * FROM (
    SELECT ... row_number() OVER (...) AS rn FROM products
) t
WHERE rn = 1;

-- CTE forması (eyni nəticə):
WITH ranked AS (
    SELECT ... row_number() OVER (...) AS rn FROM products
)
SELECT * FROM ranked WHERE rn = 1;
```
Funksional olaraq eynidir. `CTE` adətən daha oxunaqlıdır (xüsusən çox addımlı sorğularda), subquery forması daha yığcamdır. Şəxsi/kontekstual seçimdir.

*Rekursiv CTE (`WITH RECURSIVE`) hələ keçilməyib — nadir, iyerarxiya/qraf məsələləri üçün, sonra qayıdılacaq.*

---

*Əlaqəli fayllar: `postgresql-expert-kurs.md` (əsas kurs, Faza 2), `1-giris.md`, `2-sxem-qurma.md`, `3-faza1.md`.*
