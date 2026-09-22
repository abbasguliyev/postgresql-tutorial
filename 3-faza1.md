# Faza 1 — SQL Təməlləri (Ətraflı Qeydlər)

> Bu fayl, Faza 1-in bütün alt-bölmələri (1.1 SELECT icra ardıcıllığı, 1.2 WHERE filtrləmə, 1.3 data tipləri, 1.4 INSERT/UPDATE/DELETE/RETURNING/UPSERT, 1.5 constraint-lər) üzrə keçdiyimiz hər şeyin ətraflı, nümunələrlə dolu qeydidir. Unutsan, buraya qayıt.

---

## 1.1 — SELECT-in "gizli" icra ardıcıllığı

Sən sorğunu belə **yazırsan**:
```
SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT
```

Amma baza onu belə **icra edir**:
```
FROM → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT
```

**Əsas qayda:** hər addım yalnız özündən **əvvəlki** addımın nəticəsini "görür" — sonrakını yox.

### Nümunə 1 — niyə xətadır

```sql
SELECT price * 1.18 AS price_with_vat
FROM products
WHERE price_with_vat > 100;   -- ERROR: column "price_with_vat" does not exist
```
`WHERE` icra olunanda `SELECT` **hələ işə düşməyib** — ona görə `price_with_vat` adlı alias hələ mövcud deyil, baza onu tanımır.

**Doğru forma** — ifadəni `WHERE`-də təkrar yaz:
```sql
SELECT price * 1.18 AS price_with_vat
FROM products
WHERE price * 1.18 > 100;
```

### Nümunə 2 — niyə `ORDER BY`-da işləyir

```sql
SELECT price * 1.18 AS price_with_vat
FROM products
ORDER BY price_with_vat DESC;   -- OK!
```
`ORDER BY` `SELECT`-dən **sonra** icra olunur, ona görə `price_with_vat` artıq mövcuddur, alias-ı görür.

### Nəticə (qayda kimi yadda saxla)

| Bənd | Alias-ı görürmü? |
|---|---|
| `WHERE` | ❌ Yox (SELECT-dən əvvəl icra olunur) |
| `GROUP BY` | ❌ Yox |
| `HAVING` | ❌ Yox (bəzi hallarda görə bilər, amma etibar etmə) |
| `ORDER BY` | ✅ Bəli (SELECT-dən sonra icra olunur) |

---

## 1.2 — WHERE filtrləmə

### Üç-qiymətli məntiq və `NULL`

SQL-də məntiq iki yox, **üç** dəyərlidir: `true`, `false`, `NULL` (naməlum). `NULL` "boş" demək **deyil** — "məlum deyil" deməkdir.

```sql
SELECT NULL = NULL;   -- NULL  (nə true, nə false — "bilmirəm")
SELECT NULL = 5;      -- NULL
SELECT NULL IS NULL;  -- true
```

**`=` vs `IS` fərqi:**
- `=` — **dəyərləri müqayisə edən** adi operatordur, üç-qiymətli məntiqə tabedir (bir tərəf naməlumdursa, nəticə də naməlum olur).
- `IS` — "NULL-durmu?" sualı üçün yaradılmış **xüsusi** operatordur. Dəyəri yox, **vəziyyəti** yoxlayır, ona görə həmişə **qəti** (`true`/`false`) cavab verir, heç vaxt `NULL` qaytarmır.

**Qayda:** `NULL`-u yoxlamaq üçün **həmişə** `IS NULL` / `IS NOT NULL` işlət, **heç vaxt** `= NULL` yazma (bu heç vaxt işləməyəcək).

```sql
SELECT * FROM products WHERE category_id IS NULL;
SELECT * FROM products WHERE category_id IS NOT NULL;
```

### `WHERE` necə işləyir — "yalnız `true`-nu saxlayır" nə deməkdir

`WHERE` cədvəldəki **hər sətrə tək-tək** baxır, şərti hesablayır, yalnız nəticə **dəqiq `true`** olan sətirləri saxlayır. Nəticə `false` **və ya** `NULL` olarsa, sətir atılır.

### Tələ — `NOT IN` və `NULL`

```sql
SELECT * FROM products WHERE category_id NOT IN (1, 2, NULL);
```
Bu, **tamamilə boş** nəticə qaytarır — heç bir xəta vermədən!

**Niyə:** `NOT IN (1, 2, NULL)` daxildə belə işləyir: `category_id <> 1 AND category_id <> 2 AND category_id <> NULL`. Sonuncu hissə (`<> NULL`) həmişə `NULL` qaytarır → `true AND true AND NULL = NULL` → **hər sətir üçün** nəticə `NULL` olur → `WHERE` heç birini saxlamır.

Konkret misal:

| id | category_id | `NOT IN (1,2,NULL)` nəticəsi | Saxlanır? |
|---|---|---|---|
| 1 | 3 | `NULL` | ❌ Yox |
| 2 | 1 | `NULL` | ❌ Yox |
| 3 | 5 | `NULL` | ❌ Yox |

Siyahıda (və ya alt-sorğuda) bir dənə `NULL` olsa, **bütün `NOT IN` işləməz olur**. Real layihələrdə saatlarla çaşdıran məşhur bir bugdır. Həll yolu — `NOT EXISTS` (Faza 2-də).

### `<>` (bərabər deyil)

```sql
SELECT * FROM orders WHERE status <> 'cancelled';
```
`status`-u `'cancelled'` olmayan bütün sifarişləri gətirir. (`!=` da eyni mənadadır.)

### `BETWEEN`

```sql
SELECT * FROM products WHERE price BETWEEN 100 AND 200;
-- eynidir: WHERE price >= 100 AND price <= 200
```
Sərhədlər (`100` və `200`) **daxil** olmaqla.

### `IN`

```sql
SELECT * FROM customers WHERE country IN ('AZ','TR');
-- eynidir: WHERE country = 'AZ' OR country = 'TR'
```
Çoxlu `OR`-un qısa, oxunaqlı forması.

### `LIKE` / `ILIKE` — pattern axtarışı

İki xüsusi simvol:
- `%` — istənilən sayda (0 daxil) istənilən simvol
- `_` — dəqiq **bir** simvol

Pattern-i istənilən yerdə (əvvəl, orta, son, hətta bir neçə dəfə) yaza bilərsən:

| Pattern | Mənası |
|---|---|
| `'Product 1%'` | `'Product 1'` ilə **başlayan** |
| `'%Product'` | `'Product'` ilə **bitən** |
| `'%Product%'` | içində `'Product'` **olan hər yerdə** |
| `'Product_1'` | `Product` + dəqiq **bir** simvol + `1` |

```sql
SELECT * FROM products WHERE name LIKE 'Product 1%';   -- böyük/kiçik həssas
SELECT * FROM products WHERE name ILIKE 'product 1%';  -- həssas deyil (I = insensitive)
```

**Praktiki qayda:** istifadəçi axtarışı üçün adətən `ILIKE` (istifadəçi hərfləri necə yazdığını bilmirsən), dəqiq uyğunluq lazım olanda `LIKE`.

---

## Yoxlama tapşırıqları (həll olunub, cavabları düzdür)

```sql
-- Qiyməti 50-150 arası məhsullar
SELECT * FROM products WHERE price BETWEEN 50 AND 150;

-- US/DE/GB-dən olan müştərilər
SELECT * FROM customers WHERE country IN ('US', 'DE', 'GB');

-- Adında "product 5" keçən məhsullar (böyük/kiçik fərq etmədən)
SELECT * FROM products WHERE name ILIKE '%product 5%';

-- category_id-si NULL olan məhsullar
SELECT * FROM products WHERE category_id IS NULL;
```

---

## 1.3 — Data tipləri

### Pul: `numeric`, `float` yox

Kompüterlər ikilik (binar) sistemdə işləyir — bəzi adi ondalıq kəsrləri (`0.1`, `0.2` kimi) **dəqiq** ikilik ədədə çevirə bilmir, kiçik yuvarlaqlaşdırma xətaları yaranır.

```sql
SELECT 0.1::float + 0.2::float;    -- 0.30000000000000004  (səhv!)
SELECT 0.1::numeric + 0.2::numeric; -- 0.3                  (düz)
```
Bizim sxemdə `price numeric(10,2)` elə buna görədir. `numeric(p,s)` — dəqiq onluq riyaziyyatla işləyir, bu cür xəta vermir.

### Vaxt: `timestamptz`, `timestamp` yox

`timestamp` sadəcə tarix+saat saxlayır, **heç bir zaman qurşağı məlumatı olmadan**. `timestamptz` isə daxildə **UTC**-də saxlayır, göstərəndə sənin session-unun zaman qurşağına çevirir.

**Konkret problem:** `timestamp` ilə `2025-01-01 10:00:00` saxlasan — bu, Bakının saatı ilə 10:00-dır, yoxsa Londonun? Heç kim bilə bilməz. `timestamptz` bu problemi kökündən aradan qaldırır — nə vaxt, hansı zaman qurşağından yazsan, avtomatik UTC-yə çevrilib saxlanır.

**Qayda:** demək olar həmişə `timestamptz` işlət (`orders.created_at`, `products.created_at`, `customers.created_at` elə buna görədir).

### Mətn: `text` vs `varchar(n)`

Fərq faktiki olaraq **yoxdur** — performans baxımından eynidir. `varchar(n)` sadəcə uzunluğa məhdudiyyət qoyur, `text`-in limiti yoxdur.

**Qayda:** əksər hallarda sadəcə `text` işlət. `varchar(255)` "modasını" unut — köhnə vərdişdir. Limit lazımdırsa, `varchar(n)` və ya `text` + `CHECK (length(...) <= n)`.

### Digər tip kateqoriyaları (qısa)

- **Tam ədəd:** `smallint` (kiçik), `int` (adi), `bigint` (böyük — ID-lər üçün tövsiyə).
- **Boolean:** `true`/`false`/`NULL`.
- **Bahalı/qabaqcıl tiplər** (`uuid`, `jsonb`, `array`) — Faza 3-də dərinləşəcəyik.

### Tutduğumuz səhv (yaddaş üçün)

`GENERATED ALWAYS AS IDENTITY` yazarkən `IDENTITY`-ni **`IDENTIFY`** yazmışdıq (fərqli söz, sintaksis xətası verir). Diqqətli ol — `IDENTITY` = "eynilik" (PostgreSQL açar sözü), `IDENTIFY` = "eyniləşdirmək" (fel, SQL-də mənasızdır).

### `::` cast — data tipi ilə əlaqəsi

```sql
SELECT '5'::int + 3;   -- 8 (işləyir!)
```
`'5'` mətn (text) tipindədir, `::int` onu `int`-ə çevirir, sonra `3` ilə normal toplana bilir. Cast olmadan (`'5' + 3`) PostgreSQL adətən avtomatik cəhd edər, amma açıq cast həmişə daha təhlükəsiz və aydındır.

---

## 1.4 — INSERT / UPDATE / DELETE və `RETURNING`

### `RETURNING` — dəyişən sətirləri geri qaytarmaq

Normalda `INSERT`/`UPDATE`/`DELETE` sənə sadəcə "neçə sətir dəyişdi" mesajı verir (`INSERT 0 1` kimi), konkret dəyərləri göstərmir. `RETURNING` bunu dəyişir — dəyişən sətirlərin istədiyin sütunlarını **dərhal** geri qaytarır.

```sql
INSERT INTO categories (name) VALUES ('Garden') RETURNING id, name;
```
Bu, yeni yaranan sətrin `id`-sini (avtomatik yaranıb, sən əvvəlcədən bilmirsən) və `name`-ini dərhal qaytarır. **Niyə faydalıdır:** proqramlaşdırmada (backend kodunda) "yeni yaradılan obyektin ID-si nədir?" sualına ayrıca `SELECT` yazmadan cavab tapırsan — bir sorğuda hər şey bitir.

`RETURNING` `UPDATE` və `DELETE`-də də işləyir:
```sql
UPDATE products SET price = price * 1.10 WHERE category_id = 1 RETURNING id, price;
DELETE FROM order_items WHERE quantity = 0 RETURNING *;
```
`RETURNING *` — bütün sütunları qaytarır (təkcə seçilmişləri yox).

### UPSERT — `INSERT ... ON CONFLICT`

Bu, "əgər sətir artıq varsa (unikal məhdudiyyətə görə), nə etməli?" sualına cavab verir. İki forma var:

**1) `DO NOTHING`** — konflikt olsa, sadəcə heç nə etmə (xəta da vermə):
```sql
INSERT INTO categories (name) VALUES ('Books')
ON CONFLICT (name) DO NOTHING;
```
`'Books'` artıq varsa, bu sorğu **sakitcə** heç bir sətir əlavə etmir (`INSERT 0 0`), amma xəta da vermir.

**Sütun adı vermədən də yazıla bilər:** `ON CONFLICT DO NOTHING` (hədəf sütun göstərmədən) — bu, "hansı unikal məhdudiyyətdə konflikt olursa olsun, fərq etməz, heç nə etmə" deməkdir. Cədvəldə yalnız bir `UNIQUE`/`PRIMARY KEY` varsa fərq etməz, amma **`DO UPDATE`** işlədəndə sütun adını **mütləq** yazmalısan (aşağıda).

**2) `DO UPDATE`** — konflikt olsa, mövcud sətri **yenilə** (əsl "upsert"):
```sql
INSERT INTO products (sku, name, price, stock)
VALUES ('SKU-123', 'Telefon', 550.00, 30)
ON CONFLICT (sku) DO UPDATE
SET price = EXCLUDED.price, stock = EXCLUDED.stock;
```

**Vacib məntiq:** `ON CONFLICT (X) DO UPDATE`-də **`X`-in özünü yeniləmə** — bu mənasızdır (`X` artıq eynidir, elə buna görə konflikt yarandı). Sən **başqa** sütunları yeniləyirsən. `EXCLUDED` — "əlavə edilmək istənən, konflikt yaradan" sətrə istinad edir (yəni sənin `VALUES`-də yazdığın yeni dəyərlər).

**Praktiki nümunə:** hər gün təchizatçıdan məhsul siyahısı yenidən import olunur. `sku` (kod) sütunu unikal və **dəyişməz**, amma `price`/`stock` **dəyişə bilər**. `ON CONFLICT (sku) DO UPDATE SET price=..., stock=...` sayəsində: məhsul yoxdursa — əlavə olunur; varsa — qiyməti/stoku yenilənir. Bunsuz əvvəlcə `SELECT` ilə yoxlamalı, sonra `INSERT` ya `UPDATE` seçməli olardın (iki addım, "race condition" riski ilə) — `ON CONFLICT` bunu bir addımda, təhlükəsiz həll edir.

---

## 1.5 — Constraint-lər (məhdudiyyətlər)

Constraint-lər datanın bütövlüyünü **baza səviyyəsində** qoruyur — tətbiq (backend) koduna güvənmək əvəzinə, baza özü qaydaları məcbur edir. Bizim sxemi qurarkən artıq praktiki işlətdiklərimiz:

| Constraint | Nə edir | Bizim sxemdə nümunə |
|---|---|---|
| `NOT NULL` | sütun boş (`NULL`) ola bilməz | `customers.full_name`, `orders.customer_id` |
| `UNIQUE` | dəyər təkrarsız olmalı | `categories.name`, `customers.email` |
| `CHECK (şərt)` | öz xüsusi şərtini yoxlayır | `CHECK (price >= 0)`, `CHECK (status IN (...))` |
| `PRIMARY KEY` | unikal + `NOT NULL` + avtomatik indeks | `id`, kompozit: `(order_id, product_id)` |
| `FOREIGN KEY` (`REFERENCES`) | başqa cədvəldəki dəyərə istinad edir, mövcud olmayana icazə vermir | `category_id REFERENCES categories(id)` |

### Çoxsütunlu (composite) `UNIQUE`

```sql
UNIQUE (email, ref_id)
```
Bu, "**email VƏ ref_id-nin birlikdə** kombinasiyası təkrarsız olmalıdır" deməkdir — tək-tək `email` və ya `ref_id` başqa sətirlərdə təkrarlana bilər, amma **ikisi birlikdə eyni** ola bilməz. `order_items`-dəki `PRIMARY KEY (order_id, product_id)` da əslində bu məntiqin bir formasıdır — "bu iki sütunun kombinasiyası unikal olmalıdır" + əlavə olaraq ilkin açar rolunu daşıyır.

### `ON DELETE` variantları (xatırlatma)

- **`CASCADE`** — ata sətir silinəndə, ona bağlı (FK ilə istinad edən) sətirlər də **avtomatik silinir**. Bizdə: `order_items.order_id ... ON DELETE CASCADE` (sifariş silinəndə, onun sətirləri də mənasızlaşdığı üçün avtomatik silinir).
- **`SET NULL`** — ata sətir silinəndə, istinad edən sütun `NULL`-a çevrilir (məlumat itmir, sadəcə əlaqə qırılır).
- **`RESTRICT`** / **`NO ACTION`** (defolt, yazmasan bu tətbiq olunur) — silməyə **icazə verilmir**, əlaqəli sətir varsa xəta verilir. Bizdə: `products.category_id REFERENCES categories(id)` (ON DELETE yazılmayıb) — kateqoriyanı silmək istəsən, ona bağlı məhsul varsa, xəta alacaqsan.

---

*Əlaqəli fayllar: `postgresql-expert-kurs.md` (əsas kurs, Faza 1), `1-giris.md` (daxili mexanizmlər), `2-sxem-qurma.md` (sxem qurma tarixçəsi).*
