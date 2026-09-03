# PostgreSQL: Sıfırdan Expert Səviyyəyə — Tam Kurs

> Bu kurs səni PostgreSQL-də həm **developer** (sorğular, sxem dizaynı, proqramlaşdırma), həm də **DBA** (administrasiya, performans, replikasiya, backup) istiqamətlərində expert səviyyəyə çatdırmaq üçün nəzərdə tutulub.
>
> **Necə istifadə etməli:** Hər modulu sıra ilə keç. Əvvəl **nəzəri hissəni** oxu, nümunələri **öz maşınında işlət**, sonra **tapşırıqları** həll et. Həlli ancaq özün cəhd etdikdən sonra aç. Oxumaqla expert olunmur — barmaqların klaviaturada olmalıdır.

---

## Kursun quruluşu

| Faza | Mövzu | Səviyyə |
|------|-------|---------|
| 0 | Qurulum, memarlıq, `psql` | Başlanğıc |
| 1 | SQL təməlləri | Başlanğıc |
| 2 | Orta səviyyə SQL (JOIN, aqreqasiya, CTE, window) | Orta |
| 3 | Qabaqcıl data tipləri (array, JSONB, range, FTS) | Orta |
| 4 | Sxem dizaynı, normallaşdırma, indekslər | Orta-Yüksək |
| 5 | Performans və sorğu optimizasiyası | Yüksək |
| 6 | Serverdə proqramlaşdırma (PL/pgSQL, trigger, view) | Yüksək |
| 7 | Tranzaksiyalar, MVCC, konkurentlik | Yüksək |
| 8 | Administrasiya (rollar, backup, partisiyalama) | Expert |
| 9 | Replikasiya, miqyaslama, HA | Expert |
| 10 | Daxili quruluş (internals), extension-lar | Expert |
| — | Yekun layihə | Expert |

---

## Faza 0 — Qurulum, memarlıq və `psql`

### 0.1 PostgreSQL nədir və niyə fərqlidir

PostgreSQL — açıq mənbəli, **obyekt-relyasion** verilənlər bazası idarəetmə sistemidir (ORDBMS). 30+ ildir aktiv inkişaf edir. Onu MySQL-dən və digərlərindən fərqləndirən əsas cəhətlər:

- **Genişlənə bilənlik (extensibility):** öz data tiplərini, operatorlarını, indeks növlərini, funksiyalarını yaza bilərsən.
- **Standarta ciddi uyğunluq:** SQL standartına ən yaxın bazalardan biridir.
- **MVCC:** oxumalar yazmaları, yazmalar oxumaları bloklamır (Faza 7).
- **Zəngin data tipləri:** JSONB, array, range, geometrik tiplər, `hstore`, UUID və s.
- **Güclü indeks növləri:** B-tree, Hash, GiST, SP-GiST, GIN, BRIN.

### 0.2 Memarlıq — ümumi mənzərə

PostgreSQL **proses əsaslıdır** (thread yox, hər əlaqə üçün ayrı proses):

```
                 ┌──────────────────────────────────────────┐
   Klient ─────► │  postmaster (əsas proses)                │
                 │     │                                     │
                 │     ├─► backend proses (hər əlaqə üçün 1) │
                 │     ├─► background writer                 │
                 │     ├─► checkpointer                      │
                 │     ├─► WAL writer                        │
                 │     ├─► autovacuum launcher               │
                 │     └─► stats collector                   │
                 └──────────────┬───────────────────────────┘
                                │
              ┌─────────────────┼──────────────────┐
              ▼                 ▼                  ▼
        Shared Buffers      WAL (Write-        Data files
        (yaddaşda kеş)      Ahead Log)         (disk: heap, index)
```

Əsas anlayışlar:
- **Shared buffers** — yaddaşdakı səhifə keşi (default 128MB, prod-da RAM-ın ~25%-i).
- **WAL (Write-Ahead Log)** — hər dəyişiklik əvvəl loga yazılır, sonra data faylına. Bu, qəza bərpasının (crash recovery) və replikasiyanın əsasıdır.
- **Cluster / Database / Schema:** bir server instansı bir **cluster**-dir; cluster içində çox **database**; hər database içində çox **schema**; schema içində cədvəllər, funksiyalar və s.

### 0.3 Quraşdırma

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl status postgresql
```

**macOS (Homebrew):**
```bash
brew install postgresql@17
brew services start postgresql@17
```

**Docker (tövsiyə — təcrübə üçün ideal, təmiz mühit):**
```bash
docker run --name pg-lab \
  -e POSTGRES_PASSWORD=parol123 \
  -p 5432:5432 \
  -d postgres:17
```

Serverə qoşulmaq:
```bash
# sistem istifadəçisi ilə
sudo -u postgres psql

# yaxud host/port ilə
psql -h localhost -U postgres -p 5432
```

### 0.4 `psql` — sənin əsas alətin

`psql` interaktiv terminaldır. Backslash (`\`) ilə başlayan **meta-komandaları** öyrən — gündəlik iş üçün vacibdir:

| Komanda | Nə edir |
|---------|---------|
| `\l` | database-lərin siyahısı |
| `\c dbname` | başqa database-ə keç |
| `\dt` | cari sxemdəki cədvəllər |
| `\d cədvəl_adı` | cədvəlin strukturu (sütunlar, indekslər, constraint-lər) |
| `\d+ cədvəl` | daha ətraflı (ölçü, açıqlama) |
| `\di` | indekslər |
| `\df` | funksiyalar |
| `\dn` | sxemlər |
| `\du` | rollar/istifadəçilər |
| `\x` | genişlənmiş göstərmə (uzun sətirlər üçün, on/off) |
| `\timing` | sorğunun icra vaxtını göstər |
| `\e` | sorğunu editorda aç |
| `\i fayl.sql` | fayldan SQL icra et |
| `\?` | meta-komandaların köməyi |
| `\h SELECT` | SQL komandasının sintaksis köməyi |

**Məsləhət:** `\timing on` və `\x auto` demək olar ki, həmişə faydalıdır.

### 0.5 İlk database

```sql
CREATE DATABASE shop;
\c shop
CREATE TABLE ping (id serial PRIMARY KEY, msg text);
INSERT INTO ping (msg) VALUES ('salam, postgres');
SELECT * FROM ping;
```

### Faza 0 — Tapşırıqlar

1. Docker və ya lokal quraşdırma ilə serveri qaldır və `psql`-ə qoşul.
2. `SELECT version();` işlət — hansı versiyadasan?
3. `shop` adında database yarat, ona keç, `\conninfo` ilə əlaqə məlumatını yoxla.
4. `SHOW shared_buffers;` və `SHOW data_directory;` işlət. Data direktoriyasının içində hansı fayllar var (`ls -la`)?
5. `\timing on` et və `SELECT count(*) FROM generate_series(1, 1000000);` işlət. Nə qədər çəkdi?

<details>
<summary>İpucu / cavablar</summary>

- `generate_series` — çox faydalı funksiyadır, test datası üçün istifadə edəcəyik.
- Data direktoriyasında `base/`, `pg_wal/`, `global/`, `postgresql.conf` görəcəksən — bunlar Faza 10-da mənalı olacaq.
</details>

---

## Kurs boyu istifadə edəcəyimiz nümunə sxem

Bütün kurs boyu bir **onlayn mağaza** bazasından istifadə edəcəyik. İndi onu yarat — hər fazada bunun üzərində işləyəcəyik.

```sql
\c shop

CREATE TABLE customers (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   text NOT NULL,
    email       text NOT NULL UNIQUE,
    country     text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE categories (
    id      int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    text NOT NULL UNIQUE
);

CREATE TABLE products (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL,
    category_id  int REFERENCES categories(id),
    price        numeric(10,2) NOT NULL CHECK (price >= 0),
    stock        int NOT NULL DEFAULT 0 CHECK (stock >= 0),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customers(id),
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','paid','shipped','delivered','cancelled')),
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_id    bigint NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  bigint NOT NULL REFERENCES products(id),
    quantity    int NOT NULL CHECK (quantity > 0),
    unit_price  numeric(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);
```

Test datası ilə doldur (generate_series ilə süni data):

```sql
INSERT INTO categories (name)
VALUES ('Electronics'),('Books'),('Clothing'),('Home'),('Toys');

INSERT INTO customers (full_name, email, country)
SELECT
    'Customer ' || g,
    'user' || g || '@example.com',
    (ARRAY['AZ','TR','US','DE','GB'])[1 + (g % 5)]
FROM generate_series(1, 5000) AS g;

INSERT INTO products (name, category_id, price, stock, attributes)
SELECT
    'Product ' || g,
    1 + (g % 5),
    round((random() * 490 + 10)::numeric, 2),
    (random() * 200)::int,
    jsonb_build_object(
        'color', (ARRAY['red','green','blue','black'])[1 + (g % 4)],
        'weight_kg', round((random()*5)::numeric, 2)
    )
FROM generate_series(1, 2000) AS g;

INSERT INTO orders (customer_id, status, created_at)
SELECT
    1 + (random() * 4999)::int,
    (ARRAY['pending','paid','shipped','delivered','cancelled'])[1 + (g % 5)],
    now() - (random() * interval '365 days')
FROM generate_series(1, 20000) AS g;

-- hər sifarişə 1-4 məhsul
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT DISTINCT ON (o.id, p.id)
    o.id,
    p.id,
    1 + (random() * 3)::int,
    p.price
FROM orders o
CROSS JOIN LATERAL (
    SELECT id, price FROM products ORDER BY random() LIMIT 3
) p;

ANALYZE;  -- planner üçün statistikanı yenilə
```

İndi 5000 müştərin, 2000 məhsulun, 20000 sifarişin var. Real ölçüdə təcrübə üçün kifayətdir.

---

## Faza 1 — SQL Təməlləri

### 1.1 SELECT-in anatomiyası

SQL sorğusunun **məntiqi icra ardıcıllığı** yazılış ardıcıllığından fərqlidir. Bunu başa düşmək kritikdir:

```
Yazılış:  SELECT ... FROM ... WHERE ... GROUP BY ... HAVING ... ORDER BY ... LIMIT
Məntiqi:  FROM → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT
```

Buna görə `WHERE`-də `SELECT`-də verdiyin alias-ı istifadə edə bilmirsən (çünki `WHERE` `SELECT`-dən əvvəl işləyir), amma `ORDER BY`-da istifadə edə bilirsən.

```sql
-- Bu XƏTADIR: alias hələ mövcud deyil
SELECT price * 1.18 AS price_with_vat FROM products WHERE price_with_vat > 100;  -- ERROR

-- Doğru:
SELECT price * 1.18 AS price_with_vat FROM products WHERE price * 1.18 > 100;

-- ORDER BY-da alias işləyir:
SELECT price * 1.18 AS price_with_vat FROM products ORDER BY price_with_vat DESC;
```

### 1.2 WHERE — filtrləmə

**`BETWEEN`** — iki dəyər arasında olub-olmadığını yoxlayır, sərhədlər **daxil** olmaqla:
```sql
SELECT * FROM products WHERE price BETWEEN 100 AND 200;
-- eynidir: WHERE price >= 100 AND price <= 200
```

**`IN`** — dəyərin verilmiş siyahıdan biri olub-olmadığını yoxlayır (çoxlu `OR`-un qısa forması):
```sql
SELECT * FROM customers WHERE country IN ('AZ','TR');
-- eynidir: WHERE country = 'AZ' OR country = 'TR'
```

**`LIKE` / `ILIKE`** — mətndə naxış (pattern) axtarışı. İki xüsusi simvol var: `%` (istənilən sayda, 0 daxil, istənilən simvol) və `_` (dəqiq bir simvol). Bunları pattern daxilində **istənilən yerdə** (əvvəl, orta, son, hətta bir neçə dəfə) yaza bilərsən:

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
Praktiki qayda: istifadəçi axtarışı üçün adətən `ILIKE`, dəqiq uyğunluq lazım olanda `LIKE`.

**`<>`** (və ya `!=`) — "bərabər deyil":
```sql
SELECT * FROM orders WHERE status <> 'cancelled';
```

**`IS NULL` / `IS NOT NULL`** — `NULL`-u yoxlamağın **yeganə düzgün** yoludur:
```sql
SELECT * FROM products WHERE category_id IS NULL;
```

**NULL haqqında kritik qayda:** `NULL` "naməlum" deməkdir, "boş" yox. SQL-də məntiq iki yox, **üç** dəyərlidir: `true`, `false`, `NULL`. `NULL = NULL` → `NULL` (nə true, nə false) — çünki `=` **dəyərləri müqayisə edən** adi operatordur və tərəflərdən biri naməlum olanda nəticə də naməlum olur. `IS` isə fərqlidir: bu, məhz "NULL-durmu?" sualı üçün yaradılmış **xüsusi** operatordur, dəyəri yox vəziyyəti yoxlayır, ona görə həmişə qəti (`true`/`false`) cavab verir:

```sql
SELECT NULL = NULL;              -- NULL   (məlum deyil)
SELECT NULL IS NULL;             -- true
SELECT 5 IS DISTINCT FROM NULL;  -- true (NULL-ı da "normal dəyər" kimi müqayisə edir)
```

**Tələ — `NOT IN` və `NULL`:** əgər siyahıda (və ya alt-sorğuda) bir dənə belə `NULL` varsa, `NOT IN` **bütün nəticəni boşaldır**, heç xəta da vermədən:
```sql
SELECT * FROM products WHERE category_id NOT IN (1, 2, NULL);
```
Bu daxildə `category_id <> 1 AND category_id <> 2 AND category_id <> NULL` kimi işləyir. Sonuncu hissə (`<> NULL`) həmişə `NULL` verir, `AND` zənciri də ona görə hər sətir üçün `NULL` olur, `WHERE` isə `NULL`-u rədd edir → sorğu tamamilə boş qayıdır. Bu, real layihələrdə tez-tez rast gəlinən, saatlarla çaşdıran bir bugdır. Həll yolu (`NOT EXISTS`) Faza 2.3-də.

### 1.3 Data tipləri — düzgün seçim

| Kateqoriya | Tiplər | Qeyd |
|-----------|--------|------|
| Tam ədəd | `smallint`, `int`, `bigint` | ID-lər üçün `bigint` |
| Dəqiq onluq | `numeric(p,s)` | **Pul üçün mütləq bu**, `float` YOX |
| Sürüşən nöqtə | `real`, `double precision` | elmi hesablamalar |
| Mətn | `text`, `varchar(n)`, `char(n)` | əksərən `text` (performans fərqi yoxdur) |
| Tarix/vaxt | `date`, `time`, `timestamp`, `timestamptz` | **həmişə `timestamptz`** |
| Məntiqi | `boolean` | `true`/`false`/`NULL` |
| Bahalı | `uuid`, `json`, `jsonb`, `array`, `bytea` | Faza 3 |

**Vacib məsləhətlər:**
- Pul üçün `float` istifadə etmə — `0.1 + 0.2 != 0.3` problemi. `numeric` istifadə et.
- Vaxt üçün `timestamp` yox, `timestamptz` istifadə et — o, UTC-də saxlayır və zaman qurşağını düzgün idarə edir.
- `varchar(255)` "moda"sını unut — PostgreSQL-də `text` ilə `varchar` arasında performans fərqi yoxdur. Limit lazımdırsa `CHECK` və ya `varchar(n)` istifadə et, amma süni 255 seçmə.

### 1.4 INSERT / UPDATE / DELETE və RETURNING

```sql
-- INSERT ... RETURNING: əlavə edilən sətri geri qaytarır (yaradılan id-ni almaq üçün əla)
INSERT INTO categories (name) VALUES ('Garden') RETURNING id, name;

-- UPDATE
UPDATE products SET price = price * 1.10 WHERE category_id = 1 RETURNING id, price;

-- DELETE
DELETE FROM order_items WHERE quantity = 0;

-- UPSERT (INSERT ... ON CONFLICT) — çox güclü xüsusiyyət
INSERT INTO categories (name) VALUES ('Books')
ON CONFLICT (name) DO NOTHING;

INSERT INTO products (name, category_id, price)
VALUES ('Yeni məhsul', 1, 99.99)
ON CONFLICT (id) DO UPDATE
SET price = EXCLUDED.price;   -- EXCLUDED = daxil edilmək istənən sətir
```

### 1.5 Constraint-lər (məhdudiyyətlər)

Constraint-lər datanın bütövlüyünü **baza səviyyəsində** qoruyur — tətbiq koduna güvənmə, bazada tət.

```sql
-- NOT NULL, UNIQUE, CHECK, PRIMARY KEY, FOREIGN KEY, EXCLUDE
CREATE TABLE example (
    id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email   text NOT NULL UNIQUE,
    age     int CHECK (age >= 0 AND age < 150),
    ref_id  bigint REFERENCES customers(id) ON DELETE CASCADE,
    -- çoxsütunlu unikallıq:
    UNIQUE (email, ref_id)
);
```

`ON DELETE` variantları: `CASCADE` (ata silinəndə uşaqları da sil), `SET NULL`, `RESTRICT` (silməyə mane ol), `NO ACTION` (default).

### Faza 1 — Tapşırıqlar

1. Qiyməti 100-dən çox VƏ stok 50-dən az olan məhsulları tap.
2. Adı 'Product 1' ilə başlayan məhsulların sayını tap.
3. `AZ` və `TR`-dən olmayan müştəriləri email üzrə əlifba sırası ilə göstər.
4. Bütün `Electronics` (category_id=1) məhsulların qiymətini 5% artır və dəyişən sətirləri `RETURNING` ilə göstər.
5. `ON CONFLICT` istifadə edərək 'Books' kateqoriyasını təkrar əlavə etməyə cəhd et — heç nə baş verməməlidir.
6. Yeni müştəri əlavə et və `RETURNING id, created_at` ilə yaradılan id və vaxtı al.

<details>
<summary>Həllər</summary>

```sql
-- 1
SELECT * FROM products WHERE price > 100 AND stock < 50;

-- 2
SELECT count(*) FROM products WHERE name LIKE 'Product 1%';

-- 3
SELECT * FROM customers WHERE country NOT IN ('AZ','TR') ORDER BY email;

-- 4
UPDATE products SET price = round(price * 1.05, 2)
WHERE category_id = 1 RETURNING id, name, price;

-- 5
INSERT INTO categories (name) VALUES ('Books') ON CONFLICT (name) DO NOTHING;

-- 6
INSERT INTO customers (full_name, email, country)
VALUES ('Yeni Müştəri', 'yeni@example.com', 'AZ')
RETURNING id, created_at;
```
</details>

---

## Faza 2 — Orta Səviyyə SQL

### 2.1 JOIN-lər — dərindən

JOIN iki (və ya çox) cədvəli birləşdirir. Növləri:

```sql
-- INNER JOIN: yalnız hər iki tərəfdə uyğunluğu olan sətirlər
SELECT o.id, c.full_name, o.status
FROM orders o
INNER JOIN customers c ON c.id = o.customer_id;

-- LEFT JOIN: sol cədvəldəki BÜTÜN sətirlər + sağdan uyğun olanlar (yoxdursa NULL)
SELECT c.full_name, o.id AS order_id
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id;

-- Heç sifariş verməmiş müştəriləri tapmaq (anti-join pattern):
SELECT c.*
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;

-- RIGHT JOIN: LEFT-in əksi (nadir istifadə olunur)
-- FULL OUTER JOIN: hər iki tərəfin bütün sətirləri
-- CROSS JOIN: Dekart hasili (hər sətir × hər sətir)
```

**Vizual model:**
```
INNER JOIN         LEFT JOIN          FULL OUTER JOIN
   A ∩ B           A + (A∩B)          A ∪ B
  ┌──┬──┐          ┌──┬──┐            ┌──┬──┐
  │  │██│          │██│██│            │██│██│
  │  │██│  ← yalnız│██│██│  ← A-nın   │██│██│  ← hər ikisinin
  └──┴──┘   kəsişmə└──┴──┘    hamısı  └──┴──┘   hamısı
```

**Vacib nüans:** JOIN şərtini `ON`-da yoxsa `WHERE`-də yazmaq LEFT JOIN-də fərqli nəticə verir:

```sql
-- Bu, LEFT JOIN-i praktiki olaraq INNER-ə çevirir (səhv!):
SELECT c.full_name, o.status FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.status = 'paid';

-- Doğrusu — filtri ON-a qoy:
SELECT c.full_name, o.status FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id AND o.status = 'paid';
```

### 2.2 Aqreqasiya: GROUP BY, HAVING

```sql
-- Ölkə üzrə müştəri sayı
SELECT country, count(*) AS cnt
FROM customers
GROUP BY country
ORDER BY cnt DESC;

-- Aqreqat funksiyalar: count, sum, avg, min, max, string_agg, array_agg
SELECT
    o.status,
    count(*)                         AS order_count,
    round(avg(oi.quantity), 2)       AS avg_qty,
    sum(oi.quantity * oi.unit_price) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.status;

-- HAVING: qruplanmış nəticələri filtrlə (WHERE sətirləri, HAVING qrupları filtrlər)
SELECT customer_id, count(*) AS order_count
FROM orders
GROUP BY customer_id
HAVING count(*) > 5
ORDER BY order_count DESC;
```

`FILTER` — şərtli aqreqasiya üçün zərif üsul (CASE-dən oxunaqlıdır):

```sql
SELECT
    count(*)                                   AS total,
    count(*) FILTER (WHERE status = 'paid')    AS paid,
    count(*) FILTER (WHERE status = 'cancelled') AS cancelled
FROM orders;
```

`GROUPING SETS`, `ROLLUP`, `CUBE` — çoxsəviyyəli aqreqasiya (subtotals):

```sql
-- Ölkə + status üzrə, plus hər səviyyənin ümumi cəmi
SELECT country, status, count(*)
FROM customers c JOIN orders o ON o.customer_id = c.id
GROUP BY ROLLUP (country, status);
```

### 2.3 Subquery-lər (alt sorğular)

```sql
-- Skalyar subquery (bir dəyər qaytarır)
SELECT name, price,
       (SELECT avg(price) FROM products) AS avg_price
FROM products;

-- IN / NOT IN
SELECT * FROM products
WHERE category_id IN (SELECT id FROM categories WHERE name IN ('Books','Toys'));

-- EXISTS (çox vaxt IN-dən daha effektivdir və NULL-larla təhlükəsizdir)
SELECT c.* FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);

-- Korrelyasiyalı subquery: xarici sorğunun sətrinə istinad edir
SELECT p.name, p.price
FROM products p
WHERE p.price > (
    SELECT avg(price) FROM products p2 WHERE p2.category_id = p.category_id
);
```

**Diqqət — `NOT IN` və NULL tələsi:** əgər subquery NULL qaytarırsa, `NOT IN` gözlənilməz olaraq boş nəticə verə bilər. `NOT EXISTS` istifadə et.

### 2.4 CTE (Common Table Expression) — `WITH`

CTE mürəkkəb sorğuları oxunaqlı hissələrə ayırır:

```sql
WITH order_totals AS (
    SELECT order_id, sum(quantity * unit_price) AS total
    FROM order_items
    GROUP BY order_id
),
big_orders AS (
    SELECT * FROM order_totals WHERE total > 500
)
SELECT o.id, o.status, bo.total
FROM big_orders bo
JOIN orders o ON o.id = bo.order_id
ORDER BY bo.total DESC;
```

**Rekursiv CTE** — iyerarxiyalar, qraf keçidi üçün:

```sql
-- 1-dən 10-a qədər ədədlər (sadə nümunə)
WITH RECURSIVE nums AS (
    SELECT 1 AS n                       -- baza hal
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 10 -- rekursiv hissə
)
SELECT * FROM nums;

-- Real istifadə: kateqoriya ağacı (parent_id olan cədvəldə)
-- WITH RECURSIVE tree AS (
--   SELECT id, name, parent_id, 1 AS depth FROM categories WHERE parent_id IS NULL
--   UNION ALL
--   SELECT c.id, c.name, c.parent_id, t.depth+1
--   FROM categories c JOIN tree t ON c.parent_id = t.id
-- ) SELECT * FROM tree;
```

> **Performans qeydi:** PostgreSQL 12-yə qədər CTE həmişə "materializasiya" olunurdu (optimization barrier). İndi planner adətən onları inline edir. `WITH ... AS MATERIALIZED` / `NOT MATERIALIZED` ilə davranışı məcbur edə bilərsən.

### 2.5 Window (pəncərə) funksiyaları — ORTA-YÜKSƏK, çox vacib

Window funksiyaları sətirləri **qruplaşdırmadan** aqreqasiya kimi hesablamalar edir — hər sətir öz nəticəsini alır, amma "pəncərə" boyunca.

```sql
-- Hər məhsulun qiyməti + öz kateqoriyasındakı orta qiymət (sətirlər itmir!)
SELECT
    name, category_id, price,
    avg(price) OVER (PARTITION BY category_id) AS cat_avg,
    price - avg(price) OVER (PARTITION BY category_id) AS diff_from_avg
FROM products;

-- Sıralama funksiyaları
SELECT
    name, category_id, price,
    row_number() OVER (PARTITION BY category_id ORDER BY price DESC) AS rn,
    rank()       OVER (PARTITION BY category_id ORDER BY price DESC) AS rnk,
    dense_rank() OVER (PARTITION BY category_id ORDER BY price DESC) AS drnk
FROM products;

-- Hər kateqoriyanın ən bahalı 3 məhsulu (Top-N per group — klassik pattern)
SELECT * FROM (
    SELECT name, category_id, price,
           row_number() OVER (PARTITION BY category_id ORDER BY price DESC) AS rn
    FROM products
) t
WHERE rn <= 3;

-- LAG / LEAD: əvvəlki/sonrakı sətrə bax (zaman seriyaları üçün)
SELECT
    date_trunc('month', created_at) AS month,
    count(*) AS orders,
    lag(count(*)) OVER (ORDER BY date_trunc('month', created_at)) AS prev_month
FROM orders
GROUP BY 1 ORDER BY 1;

-- Yığılan cəm (running total)
SELECT
    created_at::date AS day,
    count(*) AS daily,
    sum(count(*)) OVER (ORDER BY created_at::date) AS cumulative
FROM orders GROUP BY 1 ORDER BY 1;
```

`ROWS BETWEEN` ilə çərçivəni idarə et:
```sql
-- 7 günlük hərəkətli orta
SELECT day, cnt,
       avg(cnt) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma7
FROM (SELECT created_at::date AS day, count(*) cnt FROM orders GROUP BY 1) d;
```

### Faza 2 — Tapşırıqlar

1. Hər müştərinin ümumi xərclədiyi məbləği tap (yalnız `paid`/`delivered` sifarişlər), ən çox xərcləyən 10-u göstər.
2. Heç bir sifarişi olmayan məhsulları tap (`NOT EXISTS` ilə).
3. Hər kateqoriyada neçə məhsul var və ortalama qiymət nədir? Nəticəni məhsul sayına görə azalan sırala.
4. Window funksiyası ilə: hər sifarişin `order_items`-dəki sətirlərini, həmçinin hər sifariş üçün ümumi məbləği göstər.
5. `LAG` ilə: aylıq gəliri hesabla və əvvəlki aya nisbətdə faiz dəyişikliyini tap.
6. Hər ölkə üçün ən çox xərcləyən müştərini tap (`row_number` PARTITION ilə).

<details>
<summary>Həllər</summary>

```sql
-- 1
SELECT c.id, c.full_name, sum(oi.quantity*oi.unit_price) AS spent
FROM customers c
JOIN orders o ON o.customer_id=c.id AND o.status IN ('paid','delivered')
JOIN order_items oi ON oi.order_id=o.id
GROUP BY c.id, c.full_name
ORDER BY spent DESC LIMIT 10;

-- 2
SELECT p.* FROM products p
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id=p.id);

-- 3
SELECT cat.name, count(*) AS product_count, round(avg(p.price),2) AS avg_price
FROM products p JOIN categories cat ON cat.id=p.category_id
GROUP BY cat.name ORDER BY product_count DESC;

-- 4
SELECT oi.order_id, oi.product_id, oi.quantity, oi.unit_price,
       sum(oi.quantity*oi.unit_price) OVER (PARTITION BY oi.order_id) AS order_total
FROM order_items oi;

-- 5
WITH m AS (
  SELECT date_trunc('month',o.created_at) AS mth,
         sum(oi.quantity*oi.unit_price) AS revenue
  FROM orders o JOIN order_items oi ON oi.order_id=o.id
  GROUP BY 1)
SELECT mth, revenue,
       round(100*(revenue-lag(revenue) OVER (ORDER BY mth))
             / lag(revenue) OVER (ORDER BY mth), 1) AS pct_change
FROM m ORDER BY mth;

-- 6
SELECT * FROM (
  SELECT c.country, c.full_name, sum(oi.quantity*oi.unit_price) AS spent,
         row_number() OVER (PARTITION BY c.country
                            ORDER BY sum(oi.quantity*oi.unit_price) DESC) AS rn
  FROM customers c JOIN orders o ON o.customer_id=c.id
  JOIN order_items oi ON oi.order_id=o.id
  GROUP BY c.country, c.id, c.full_name
) t WHERE rn=1;
```
</details>

---

## Faza 3 — Qabaqcıl Data Tipləri

### 3.1 Array-lar

PostgreSQL sütunda massiv saxlaya bilir:

```sql
CREATE TABLE posts (
    id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title text,
    tags  text[]                       -- massiv tipi
);
INSERT INTO posts (title, tags) VALUES
  ('SQL 101', ARRAY['sql','database','beginner']),
  ('PG tuning', '{postgres,performance,dba}');  -- alternativ sintaksis

-- Sorğular
SELECT * FROM posts WHERE 'sql' = ANY(tags);          -- element var?
SELECT * FROM posts WHERE tags @> ARRAY['postgres'];  -- massiv daxildir?
SELECT * FROM posts WHERE tags && ARRAY['sql','dba']; -- kəsişmə var?
SELECT title, array_length(tags,1) AS tag_count FROM posts;
SELECT title, unnest(tags) AS tag FROM posts;         -- massivi sətirlərə aç
```

### 3.2 JSON və JSONB — çox vacib

`json` mətn kimi saxlanır (formatı qoruyur, yavaş), `jsonb` binar kimi (indekslənə bilir, sürətli). **Demək olar ki, həmişə `jsonb` istifadə et.**

```sql
-- Bizim products.attributes artıq jsonb-dir
SELECT name, attributes FROM products LIMIT 3;

-- Operatorlar:
SELECT attributes -> 'color'   FROM products LIMIT 1;   -- jsonb qaytarır
SELECT attributes ->> 'color'  FROM products LIMIT 1;   -- text qaytarır
SELECT attributes #> '{a,b}'   FROM products LIMIT 1;   -- dərin yol (jsonb)
SELECT attributes #>> '{a,b}'  FROM products LIMIT 1;   -- dərin yol (text)

-- Filtr
SELECT name FROM products WHERE attributes ->> 'color' = 'red';

-- Containment (@>) — GIN indekslə çox sürətli
SELECT name FROM products WHERE attributes @> '{"color":"blue"}';

-- Açar var?
SELECT * FROM products WHERE attributes ? 'weight_kg';

-- Dəyişdirmə
UPDATE products SET attributes = attributes || '{"featured":true}'::jsonb
WHERE id = 1;
UPDATE products SET attributes = jsonb_set(attributes, '{color}', '"gold"')
WHERE id = 1;
UPDATE products SET attributes = attributes - 'featured' WHERE id = 1;  -- açar sil

-- JSON qurma və açma
SELECT jsonb_build_object('id', id, 'name', name, 'attrs', attributes)
FROM products LIMIT 1;
SELECT jsonb_agg(jsonb_build_object('name', name, 'price', price))
FROM products WHERE category_id = 1;

-- jsonb-ni cədvələ çevir
SELECT * FROM jsonb_each('{"a":1,"b":2}'::jsonb);
SELECT * FROM jsonb_array_elements('[1,2,3]'::jsonb);
```

JSONB üçün **GIN indeks** (Faza 4-də dərinləşəcək):
```sql
CREATE INDEX idx_products_attrs ON products USING gin (attributes);
-- İndi `attributes @> '{"color":"blue"}'` sorğuları çox sürətli işləyir.
```

### 3.3 Range (interval) tipləri

```sql
-- int4range, numrange, tsrange, tstzrange, daterange
CREATE TABLE reservations (
    room_id int,
    period  tstzrange,
    EXCLUDE USING gist (room_id WITH =, period WITH &&)  -- üst-üstə düşməni qadağan et!
);
INSERT INTO reservations VALUES (1, '[2025-01-01, 2025-01-05)');
-- Bu, üst-üstə düşdüyü üçün XƏTA verəcək:
-- INSERT INTO reservations VALUES (1, '[2025-01-03, 2025-01-10)');

SELECT * FROM reservations WHERE period @> now();       -- indi aktivdir?
SELECT '[1,10)'::int4range @> 5;                        -- 5 aralıqdadır?
SELECT '[1,5)'::int4range && '[3,8)'::int4range;        -- kəsişir?
```

Bu `EXCLUDE ... USING gist` konstruksiyası — otaq rezervasiyaları, cədvəl planlaşdırması üçün çox güclü xüsusiyyətdir; başqa bazalarda tapmaq çətindir.

### 3.4 Enum və composite tiplər

```sql
CREATE TYPE mood AS ENUM ('sad','ok','happy');
CREATE TABLE feels (person text, current_mood mood);
-- Enum-lar daxili olaraq sıralıdır: 'sad' < 'ok' < 'happy'

CREATE TYPE address AS (street text, city text, zip text);
CREATE TABLE people (name text, home address);
INSERT INTO people VALUES ('Ali', ROW('Nizami 1','Baku','AZ1000'));
SELECT (home).city FROM people;
```

### 3.5 Full Text Search (FTS)

PostgreSQL daxili mətn axtarışı — ayrıca Elasticsearch olmadan çox iş görür.

```sql
-- tsvector (indekslənən sənəd) və tsquery (axtarış)
SELECT to_tsvector('english', 'The quick brown foxes are jumping');
-- 'brown':3 'fox':4 'jump':6 'quick':2  ← köklərə (lemma) endirir

SELECT to_tsvector('english','quick brown fox') @@ to_tsquery('english','fox & quick');
-- true

-- Real istifadə: axtarış sütunu + GIN indeks
ALTER TABLE products ADD COLUMN search tsvector
  GENERATED ALWAYS AS (to_tsvector('english', name)) STORED;
CREATE INDEX idx_products_search ON products USING gin (search);

SELECT name FROM products
WHERE search @@ to_tsquery('english', 'product & 1:*')
LIMIT 5;

-- Reytinq (ranking)
SELECT name, ts_rank(search, q) AS rank
FROM products, to_tsquery('english','product') q
WHERE search @@ q
ORDER BY rank DESC LIMIT 5;
```

### Faza 3 — Tapşırıqlar

1. `products.attributes`-də rəngi 'blue' olan məhsulları `@>` operatoru ilə tap. Sonra GIN indeks yarat və `EXPLAIN` ilə fərqi gör (Faza 5-ə körpü).
2. Bütün məhsullara `attributes`-ə `"in_stock": true/false` açarı əlavə et (stock > 0 şərtinə görə) `jsonb_set` və ya `||` ilə.
3. `weight_kg`-si 3-dən çox olan məhsulları tap (JSONB-dən text alıb `numeric`-ə çevir).
4. Bir `tags text[]` sütunu olan cədvəl yarat, bir neçə sətir əlavə et, `unnest` ilə hər tag üçün neçə post olduğunu hesabla.
5. `daterange` və `EXCLUDE` constraint ilə otaq rezervasiya cədvəli qur; üst-üstə düşən rezervasiyanın rədd edildiyini yoxla.

<details>
<summary>Həllər</summary>

```sql
-- 1
SELECT name FROM products WHERE attributes @> '{"color":"blue"}';
CREATE INDEX idx_products_attrs ON products USING gin (attributes);
EXPLAIN ANALYZE SELECT name FROM products WHERE attributes @> '{"color":"blue"}';

-- 2
UPDATE products SET attributes =
  attributes || jsonb_build_object('in_stock', stock > 0);

-- 3
SELECT name, (attributes->>'weight_kg')::numeric AS w
FROM products WHERE (attributes->>'weight_kg')::numeric > 3;

-- 4
CREATE TABLE t (id serial, tags text[]);
INSERT INTO t (tags) VALUES ('{a,b}'),('{b,c}'),('{a}');
SELECT unnest(tags) AS tag, count(*) FROM t GROUP BY 1 ORDER BY 2 DESC;

-- 5 yuxarıda 3.3-də göstərilib
```
</details>

---

## Faza 4 — Sxem Dizaynı, Normallaşdırma və İndekslər

### 4.1 Normallaşdırma

Normallaşdırma — datanı təkrarlanmanı (redundancy) və anomaliyaları azaltmaq üçün cədvəllərə bölmək prosesidir.

- **1NF:** hər xana atomikdir (massiv/təkrarlanan qrup yox), hər sətir unikaldır.
- **2NF:** 1NF + qeyri-açar sütunların hamısı **tam** ilkin açardan asılıdır (kompozit açarda qismən asılılıq yoxdur).
- **3NF:** 2NF + tranzitiv asılılıq yoxdur (qeyri-açar sütun başqa qeyri-açar sütundan asılı deyil).
- **BCNF:** 3NF-in daha ciddi variantı.

**Praktik qayda:** əvvəl 3NF-ə normallaşdır, sonra performans üçün **şüurlu şəkildə** denormallaşdır (məsələn, hesabat üçün əvvəlcədən hesablanmış cəmlər). Öncədən optimallaşdırma etmə.

**Nümunə anomaliya:** əgər sifariş cədvəlində müştəri adını da saxlasan, müştəri adı dəyişəndə bütün sifarişləri yeniləməli olacaqsan (update anomaliyası). Ona görə `customer_id` foreign key saxlayırıq.

### 4.2 Açarlar: təbii vs süni (surrogate)

- **Süni açar** (`GENERATED ALWAYS AS IDENTITY`, ya `bigint`) — sabit, kiçik, JOIN üçün effektiv. Əksər hallarda tövsiyə olunur.
- **`serial` vs `IDENTITY`:** `serial` köhnə üsuldur; müasir kod `GENERATED ... AS IDENTITY` istifadə etməlidir (standart, daha təhlükəsiz).
- **UUID** — paylanmış sistemlərdə, açarı klient yaratmalı olanda. Mənfi: `uuid v4` təsadüfidir → B-tree indeksdə lokallıq pisdir. `uuidv7` (vaxt-ardıcıl) daha yaxşıdır.

### 4.3 İndekslər — DƏRİNDƏN (performansın ürəyi)

İndeks — sorğunu sürətləndirən ayrıca data strukturudur. Amma **hər indeks yazma əməliyyatını yavaşladır** və yer tutur. Balans lazımdır.

#### B-tree (default)
Bərabərlik və diapazon üçün: `=`, `<`, `>`, `BETWEEN`, `ORDER BY`, `LIKE 'prefix%'`.
```sql
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_created  ON orders (created_at);
```

#### Kompozit (çoxsütunlu) indeks və sütun sırası
Sütun sırası **kritikdir**. `(a, b)` indeksi `WHERE a=...`, `WHERE a=... AND b=...` üçün işləyir, amma **tək** `WHERE b=...` üçün adətən işləmir.
```sql
CREATE INDEX idx_oi_order_product ON order_items (order_id, product_id);
-- Qayda: bərabərlik şərtli sütunlar əvvəl, diapazon/sort sonra.
```

#### Partial (qismən) indeks
Yalnız sətirlərin bir hissəsini indeksləyir — kiçik və sürətli:
```sql
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';
-- Yalnız 'pending' sifarişləri axtaranda istifadə olunur, indeks kiçik qalır.
```

#### Expression (ifadə) indeks
Hesablanmış dəyər üzərində indeks:
```sql
CREATE INDEX idx_customers_lower_email ON customers (lower(email));
-- İndi bu sürətlidir:
SELECT * FROM customers WHERE lower(email) = 'user5@example.com';
```

#### Covering indeks (INCLUDE) — index-only scan
Sorğuya lazım olan bütün sütunları indeksə daxil et → cədvələ heç toxunmadan cavab:
```sql
CREATE INDEX idx_orders_cust_incl ON orders (customer_id) INCLUDE (status, created_at);
```

#### GIN — massiv, JSONB, FTS üçün
```sql
CREATE INDEX idx_products_attrs ON products USING gin (attributes);         -- @>, ?
CREATE INDEX idx_products_search ON products USING gin (search);            -- FTS
-- pg_trgm ilə ILIKE '%...%' üçün:
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
-- İndi `name ILIKE '%pro%'` indekslə işləyir!
```

#### GiST — həndəsə, range, "yaxınlıq" axtarışı
```sql
CREATE INDEX idx_res_period ON reservations USING gist (period);
-- EXCLUDE constraint-lər, range üst-üstə düşmə, KNN axtarışı üçün.
```

#### BRIN — çox böyük, təbii sıralı cədvəllər üçün (kiçik indeks)
```sql
CREATE INDEX idx_orders_created_brin ON orders USING brin (created_at);
-- Milyardlarla sətir, vaxt üzrə sıralı data üçün ideal. Çox az yer tutur.
```

#### Digər faydalı əmrlər
```sql
CREATE UNIQUE INDEX ... ;            -- unikallıq + indeks
CREATE INDEX CONCURRENTLY ... ;      -- cədvəli bloklamadan (prod-da mütləq)
DROP INDEX CONCURRENTLY ... ;
REINDEX INDEX ... ;                  -- şişmiş (bloated) indeksi yenidən qur
SELECT * FROM pg_stat_user_indexes;  -- indeks istifadə statistikası
```

### Faza 4 — Tapşırıqlar
1. `orders (customer_id)`-ə indeks yaratmadan və yaratdıqdan sonra `EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;` işlət, `Seq Scan` → `Index Scan` dəyişikliyini gör.
2. `lower(email)` üzərində expression indeks yarat, effektini `EXPLAIN` ilə təsdiqlə.
3. `pg_trgm` ilə `name ILIKE '%Product 15%'` sorğusunu indekslə.
4. Yalnız `status = 'pending'` sifarişlər üçün partial indeks yarat.
5. `pg_stat_user_indexes`-ə bax — hansı indekslərin `idx_scan = 0` (heç istifadə olunmayan)? Onları silmək olarmı?

---

## Faza 5 — Performans və Sorğu Optimizasiyası (YÜKSƏK — expert olmağın açarı)

### 5.1 EXPLAIN və EXPLAIN ANALYZE

`EXPLAIN` planı göstərir (icra etmir). `EXPLAIN ANALYZE` **həqiqətən icra edir** və real vaxtları göstərir.

```sql
EXPLAIN ANALYZE
SELECT c.full_name, count(*)
FROM customers c JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.full_name
ORDER BY count(*) DESC LIMIT 10;
```

Faydalı variantlar:
```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT) SELECT ...;
```
- `BUFFERS` — neçə səhifə keşdən (`shared hit`) vs diskdən (`read`) oxundu. Çox vacib!

### 5.2 Planı oxumaq — düyün (node) növləri

```
Sort  (cost=... rows=... width=...) (actual time=... rows=... loops=...)
  ->  Hash Join  (cost=...)
        Hash Cond: (o.customer_id = c.id)
        ->  Seq Scan on orders o
        ->  Hash
              ->  Seq Scan on customers c
```

Düyün növləri və mənası:
- **Seq Scan** — cədvəli baştan sona oxu. Kiçik cədvəl və ya sətirlərin çoxu lazım olanda normaldır; kiçik nəticə üçün pisdir (indeks lazımdır).
- **Index Scan** — indeksdən oxu, sonra cədvəldən sətir götür.
- **Index Only Scan** — cavab tam indeksdən gəlir (covering indeks), cədvələ toxunmur. Ən sürətli.
- **Bitmap Index Scan + Bitmap Heap Scan** — orta seçicilikdə (indeks + cədvəl birləşməsi).
- **Nested Loop** — kiçik data dəstləri üçün yaxşı JOIN.
- **Hash Join** — böyük data dəstləri üçün yaxşı (bir tərəfi hash cədvəlinə yığır).
- **Merge Join** — hər iki tərəf sıralıdırsa.

### 5.3 Ən kritik bacarıq: estimated vs actual rows

Plan pis olanda əsas səbəb: **planner-in sətir sayı təxmini (`rows=`) real (`actual rows=`) ilə çox fərqlənir**. Bu, statistikanın köhnə olduğunu göstərir.

```sql
ANALYZE orders;              -- statistikanı yenilə
-- Çox təkrarlanan/nadir dəyərlər üçün statistika dərinliyini artır:
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 1000;
ANALYZE orders;
```

Sütunlararası korrelyasiya üçün **genişləndirilmiş statistika**:
```sql
CREATE STATISTICS s_orders (dependencies, ndistinct)
  ON customer_id, status FROM orders;
ANALYZE orders;
```

### 5.4 Ümumi performans problemləri və həlləri

| Problem | Simptom | Həll |
|---------|---------|------|
| İndeks yoxdur | böyük cədvəldə `Seq Scan` + filtr | uyğun indeks yarat |
| Sütuna funksiya tətbiqi | `WHERE lower(email)=...` indeks yoxdur | expression indeks |
| `LIKE '%...%'` | əvvəl wildcard | `pg_trgm` GIN indeks |
| N+1 sorğu | döngüdə minlərlə sorğu | JOIN və ya `IN` ilə birləşdir |
| Köhnə statistika | təxmin ≠ real | `ANALYZE`, statistics target |
| İmplisit tip çevrilməsi | `WHERE bigint_col = '5'` | tipləri uyğunlaşdır |
| Şişmə (bloat) | cədvəl real datadan böyük | `VACUUM`, autovacuum tənzimi |

### 5.5 VACUUM, autovacuum və bloat

MVCC səbəbindən (Faza 7) `UPDATE`/`DELETE` köhnə sətir versiyalarını (**dead tuples**) dərhal silmir. `VACUUM` onları təmizləyir.

```sql
VACUUM (VERBOSE, ANALYZE) orders;
VACUUM FULL orders;   -- cədvəli tam yenidən yazır (EKSKLÜZİV kilid! ehtiyatla)

-- Dead tuple və şişmə statistikası
SELECT relname, n_live_tup, n_dead_tup,
       round(100*n_dead_tup::numeric / nullif(n_live_tup+n_dead_tup,0),1) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

**Autovacuum** — arxa planda avtomatik işləyir. Aktiv (yüksək write) cədvəllər üçün onu aqressivləşdir:
```sql
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.05,   -- default 0.2
  autovacuum_vacuum_cost_delay = 2
);
```

### 5.6 Əsas konfiqurasiya parametrləri (performans üçün)

```sql
SHOW shared_buffers;         -- RAM-ın ~25%-i
SHOW effective_cache_size;   -- RAM-ın ~50-75%-i (planner-a məsləhət)
SHOW work_mem;               -- sort/hash üçün əməliyyat başına yaddaş
SHOW maintenance_work_mem;   -- VACUUM/CREATE INDEX üçün
SHOW max_connections;        -- adətən çox yüksək olmamalıdır (pooler istifadə et)
SHOW random_page_cost;       -- SSD-də 1.1 (default 4 HDD üçündür)
```

> `work_mem` diqqətli tənzimlə: hər sorğu, hər sort/hash əməliyyatı üçün ayrıca ayrılır. Çox yüksək dəyər OOM-a gətirə bilər.

### 5.7 Diaqnostika üçün mütləq alətlər

```sql
-- pg_stat_statements — ən "bahalı" sorğuları tapmaq üçün #1 alət
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT query, calls, round(total_exec_time::numeric,1) AS total_ms,
       round(mean_exec_time::numeric,2) AS mean_ms, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;

-- Hazırda işləyən sorğular
SELECT pid, state, wait_event_type, wait_event,
       now()-query_start AS duration, query
FROM pg_stat_activity
WHERE state <> 'idle' ORDER BY duration DESC;

-- Uzun sorğunu dayandır
SELECT pg_cancel_backend(PID);   -- yumşaq
SELECT pg_terminate_backend(PID);-- sərt
```

### Faza 5 — Tapşırıqlar
1. `SELECT * FROM orders WHERE customer_id = 42` üçün `EXPLAIN (ANALYZE, BUFFERS)` işlət. `Seq Scan`-dır? İndeks yarat, yenidən işlət, `Buffers`-in necə dəyişdiyinə bax.
2. Elə bir sorğu yaz ki, planner-in `rows=` təxmini real dəyərdən 10x fərqlənsin. `ANALYZE` işlət, düzəldiyini yoxla.
3. `WHERE name ILIKE '%15%'` sorğusunu əvvəl indeks olmadan, sonra `pg_trgm` indeksi ilə ölç (`\timing`).
4. Bir neçə `UPDATE` işlət, sonra `pg_stat_user_tables`-də `n_dead_tup`-a bax, `VACUUM` işlət, azaldığını gör.
5. `pg_stat_statements` qur, kursun sorğularını işlət, ən bahalı 5 sorğunu tap.

---

## Faza 6 — Serverdə Proqramlaşdırma

### 6.1 View və Materialized View

```sql
-- View — saxlanmış sorğu (data saxlamır, hər dəfə yenidən işləyir)
CREATE VIEW order_summary AS
SELECT o.id, c.full_name, o.status,
       sum(oi.quantity*oi.unit_price) AS total
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, c.full_name, o.status;

SELECT * FROM order_summary WHERE total > 1000;

-- Materialized view — nəticəni fiziki saxlayır (hesabatlar üçün əla)
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT created_at::date AS day, sum(oi.quantity*oi.unit_price) AS revenue
FROM orders o JOIN order_items oi ON oi.order_id=o.id
GROUP BY 1;

CREATE UNIQUE INDEX ON daily_revenue (day);          -- CONCURRENTLY refresh üçün lazım
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;-- bloklamadan yenilə
```

### 6.2 Funksiyalar — SQL və PL/pgSQL

```sql
-- Sadə SQL funksiyası
CREATE OR REPLACE FUNCTION order_total(p_order_id bigint)
RETURNS numeric LANGUAGE sql STABLE AS $$
    SELECT coalesce(sum(quantity*unit_price),0)
    FROM order_items WHERE order_id = p_order_id;
$$;
SELECT order_total(1);

-- PL/pgSQL — prosedur məntiq, dəyişənlər, döngülər
CREATE OR REPLACE FUNCTION apply_discount(p_category int, p_pct numeric)
RETURNS int LANGUAGE plpgsql AS $$
DECLARE
    affected int;
BEGIN
    UPDATE products
    SET price = round(price * (1 - p_pct/100), 2)
    WHERE category_id = p_category;
    GET DIAGNOSTICS affected = ROW_COUNT;
    RAISE NOTICE 'Endirim tətbiq edildi: % məhsul', affected;
    RETURN affected;
END;
$$;
SELECT apply_discount(1, 10);
```

**Volatility markerləri** (planner optimizasiyası üçün vacib):
- `IMMUTABLE` — eyni giriş → həmişə eyni nəticə (məs. `lower()`). İndekslənə bilər.
- `STABLE` — bir sorğu daxilində sabit (məs. `now()`).
- `VOLATILE` (default) — hər çağırışda dəyişə bilər (məs. `random()`).

### 6.3 Stored Procedure (tranzaksiya idarəsi ilə)

Funksiyadan fərqli olaraq **prosedur** daxilində `COMMIT`/`ROLLBACK` edə bilir:
```sql
CREATE PROCEDURE reconcile() LANGUAGE plpgsql AS $$
BEGIN
    UPDATE orders SET status='delivered' WHERE status='shipped';
    COMMIT;
    -- başqa işlər...
END; $$;
CALL reconcile();
```

### 6.4 Trigger-lər

Trigger — INSERT/UPDATE/DELETE baş verəndə avtomatik işləyən funksiya.

```sql
-- updated_at avtomatik yeniləmə (klassik pattern)
ALTER TABLE products ADD COLUMN updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_products_updated
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Audit log trigger nümunəsi
CREATE TABLE product_audit (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id bigint, old_price numeric, new_price numeric, changed_at timestamptz DEFAULT now()
);
CREATE OR REPLACE FUNCTION audit_price() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.price IS DISTINCT FROM OLD.price THEN
        INSERT INTO product_audit(product_id, old_price, new_price)
        VALUES (OLD.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END; $$;
CREATE TRIGGER trg_audit_price
AFTER UPDATE ON products FOR EACH ROW EXECUTE FUNCTION audit_price();
```

Trigger vaxtları: `BEFORE`/`AFTER`/`INSTEAD OF` (view-lar üçün), `FOR EACH ROW`/`FOR EACH STATEMENT`.

### Faza 6 — Tapşırıqlar
1. Müştərinin ümumi xərcini qaytaran `customer_spent(bigint)` funksiyası yaz.
2. `daily_revenue` materialized view yarat, `CONCURRENTLY` refresh üçün unique indeks əlavə et.
3. Hər sifarişə `order_items` əlavə/silinəndə `orders`-də saxlanan `total_amount` sütununu yeniləyən trigger yaz (denormalizasiya + trigger).
4. `products`-də qiymət dəyişəndə audit log yazan trigger qur, bir neçə UPDATE et, audit cədvəlini yoxla.
5. PL/pgSQL funksiyası yaz ki, verilmiş ölkə üçün müştəri sayına görə "small/medium/large" mətn qaytarsın (`IF/ELSIF`).

---

## Faza 7 — Tranzaksiyalar, MVCC və Konkurentlik (YÜKSƏK)

### 7.1 ACID və tranzaksiyalar

```sql
BEGIN;
    UPDATE products SET stock = stock - 1 WHERE id = 5;
    INSERT INTO order_items VALUES (...);
COMMIT;   -- ya ROLLBACK;

-- SAVEPOINT — qismən geri qaytarma
BEGIN;
    UPDATE products SET stock = stock - 1 WHERE id = 5;
    SAVEPOINT sp1;
    UPDATE products SET stock = stock - 999 WHERE id = 6;  -- CHECK pozula bilər
    ROLLBACK TO sp1;   -- yalnız 2-ci UPDATE geri qaytar
COMMIT;
```

### 7.2 MVCC — Multi-Version Concurrency Control

PostgreSQL-in ürəyi. Hər sətrin **çox versiyası** ola bilər. Hər tranzaksiya "snapshot" görür:
- **Oxumalar yazmaları bloklamır, yazmalar oxumaları bloklamır.**
- `UPDATE` əslində köhnə sətri "ölü" (dead) işarələyir və yeni versiya yaradır (`xmin`/`xmax` sistem sütunları versiyaları izləyir).
- Ölü sətirləri `VACUUM` təmizləyir (Faza 5).

```sql
SELECT xmin, xmax, * FROM products WHERE id = 1;  -- gizli sistem sütunları
```

### 7.3 İzolyasiya səviyyələri

| Səviyyə | Dirty read | Non-repeatable read | Phantom read | Serialization anomaly |
|---------|-----------|---------------------|--------------|----------------------|
| Read Committed (default) | yox | **ola bilər** | **ola bilər** | ola bilər |
| Repeatable Read | yox | yox | yox* | ola bilər |
| Serializable | yox | yox | yox | **yox** |

> PostgreSQL heç vaxt "dirty read"-ə icazə vermir. Repeatable Read faktiki olaraq snapshot izolyasiyası verir və phantom-ları da qarşılayır.

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
    SELECT count(*) FROM orders;   -- bütün tranzaksiya boyu eyni snapshot
    -- ... başqa sessiya sətir əlavə etsə də, biz görmürük
COMMIT;

BEGIN ISOLATION LEVEL SERIALIZABLE;
    -- konflikt olarsa COMMIT-də serialization_failure (40001) alacaqsan → yenidən cəhd et
COMMIT;
```

**Serializable ilə işləyəndə tətbiqdə retry məntiqi olmalıdır** (`40001` xətası → tranzaksiyanı təkrarla).

### 7.4 Locking (kilidləmə)

```sql
-- Sətir kilidi: eyni sətri iki sessiya eyni anda yeniləməsin
BEGIN;
SELECT * FROM products WHERE id = 5 FOR UPDATE;   -- sətri kilidlə
-- başqa sessiyanın FOR UPDATE-i bu COMMIT-ə qədər gözləyir
UPDATE products SET stock = stock - 1 WHERE id = 5;
COMMIT;

-- Skip locked — növbə (queue) emalı üçün əla
SELECT * FROM jobs WHERE status='pending'
ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 1;

-- FOR SHARE, FOR NO KEY UPDATE, NOWAIT variantları da var
```

### 7.5 Deadlock (qarşılıqlı kilidlənmə)

İki tranzaksiya bir-birinin kilidini gözləyəndə baş verir. PostgreSQL onu aşkarlayır və birini `deadlock detected` xətası ilə ləğv edir.

**Qarşısını almaq:** həmişə obyektləri **eyni ardıcıllıqla** kilidləyin (məs. həmişə kiçik id-dən böyüyə). Kilidləri qısa saxla.

### 7.6 Advisory locks — tətbiq səviyyəli kilidlər
```sql
SELECT pg_advisory_lock(12345);    -- öz məntiqi kilidin
-- ... kritik iş ...
SELECT pg_advisory_unlock(12345);
-- İstifadə: bir vaxtda yalnız bir instansın cron job işlətməsini təmin et.
```

### Faza 7 — Tapşırıqlar
1. İki `psql` sessiyası aç. Birində `BEGIN; UPDATE products SET price=price+1 WHERE id=1;` (COMMIT etmə). O biri sessiyada eyni sətri UPDATE et — ikincinin gözlədiyini gör. Birincidə COMMIT et.
2. `REPEATABLE READ`-də sessiya aç, `count(*) FROM orders` oxu. Başqa sessiyada sifariş əlavə et. İlk sessiyada yenidən oxu — say dəyişdimi? COMMIT-dən sonra?
3. Süni deadlock yarat: iki sessiyada sətirləri əks ardıcıllıqla kilidlə. `deadlock detected` xətasını gör.
4. `FOR UPDATE SKIP LOCKED` ilə sadə "iş növbəsi" (job queue) emalı simulyasiya et.
5. `SERIALIZABLE`-də iki eyni-vaxtlı tranzaksiya yaz ki, biri `40001` alsın; retry məntiqini təsvir et.

---

## Faza 8 — Administrasiya (EXPERT)

### 8.1 Rollar, istifadəçilər və icazələr

PostgreSQL-də "user" və "group" əslində eyni şeydir — **rol**. Rol login edə bilər (`LOGIN`) və ya qrup kimi işləyə bilər.

```sql
-- Rol yaratma
CREATE ROLE app_read;                             -- qrup rolu (login yoxdur)
CREATE ROLE analyst LOGIN PASSWORD 'parol';       -- login edən istifadəçi
CREATE ROLE admin LOGIN PASSWORD 'parol' CREATEDB CREATEROLE;

-- Səlahiyyət vermə (GRANT)
GRANT CONNECT ON DATABASE shop TO app_read;
GRANT USAGE ON SCHEMA public TO app_read;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;
-- Gələcəkdə yaradılacaq cədvəllərə də avtomatik:
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_read;

-- Rolu istifadəçiyə "üzvlük" kimi ver
GRANT app_read TO analyst;

-- Səlahiyyəti geri al
REVOKE SELECT ON products FROM app_read;
```

**Ən az imtiyaz prinsipi:** tətbiq istifadəçisinə yalnız lazım olanı ver. `SUPERUSER`-i gündəlik iş üçün istifadə etmə.

### 8.2 Row-Level Security (RLS) — sətir səviyyəli təhlükəsizlik

Fərqli istifadəçilər eyni cədvəldə yalnız öz sətirlərini görsün:
```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_orders ON orders
    USING (customer_id = current_setting('app.current_customer')::bigint);
-- Tətbiq hər əlaqədə: SET app.current_customer = '42';
-- İndi bu istifadəçi yalnız 42-nin sifarişlərini görür.
```

### 8.3 Backup və Restore

**Məntiqi backup (`pg_dump`)** — SQL/arxiv formatı, versiyalar arası köçürmə üçün:
```bash
# Bir database
pg_dump -Fc -d shop -f shop.dump          # custom format (sıxılmış, sürətli restore)
pg_dump -Fp -d shop -f shop.sql           # düz SQL

# Restore
pg_restore -d shop_new --clean --if-exists shop.dump
psql -d shop_new -f shop.sql

# Yalnız sxem / yalnız data
pg_dump -s -d shop -f schema.sql
pg_dump -a -d shop -f data.sql

# Bütün cluster (rollarla birlikdə)
pg_dumpall -f full.sql
```

**Fiziki backup (`pg_basebackup`)** — bütün data direktoriyası, replikasiya və PITR üçün:
```bash
pg_basebackup -D /backup/base -Fp -Xs -P
```

### 8.4 Point-In-Time Recovery (PITR) — expert səviyyə

WAL arxivləmə + baza backup = istənilən ana bərpa. Konsepsiya:
1. `archive_mode = on`, `archive_command = 'cp %p /wal_archive/%f'` (postgresql.conf).
2. `pg_basebackup` ilə əsas snapshot al.
3. Qəza baş verəndə: base backup-ı bərpa et + `recovery_target_time = '2025-06-01 14:30:00'` təyin et → WAL-ları həmin ana qədər oynat.

Bu, "səhvən DROP TABLE etdim, 5 dəqiqə əvvələ qayıtmaq istəyirəm" ssenarisinin həllidir.

### 8.5 Partisiyalama (partitioning) — böyük cədvəllər üçün

Böyük cədvəli fiziki alt-cədvəllərə bölmək:
```sql
-- Vaxt üzrə RANGE partisiyalama (ən çox istifadə olunan)
CREATE TABLE events (
    id     bigint GENERATED ALWAYS AS IDENTITY,
    ts     timestamptz NOT NULL,
    data   jsonb
) PARTITION BY RANGE (ts);

CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_2025_02 PARTITION OF events
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Üstünlüklər: köhnə partisiyanı ani silmək (DROP TABLE, DELETE deyil),
-- partition pruning (planner yalnız lazımi partisiyaları oxuyur), paralel VACUUM.
-- LIST və HASH partisiyalama da var.
```

Praktikada partisiya idarəçiliyi üçün `pg_partman` extension-i istifadə olunur (avtomatik partisiya yaradır/silir).

### 8.6 Connection pooling

PostgreSQL hər əlaqə üçün ayrı proses açır — minlərlə əlaqə bahalıdır. **PgBouncer** kimi pooler istifadə et:
```
Tətbiq (1000 əlaqə) → PgBouncer → PostgreSQL (20 real əlaqə)
```
Rejimlər: `session` (default), `transaction` (ən çox istifadə olunan, effektiv), `statement`.

### Faza 8 — Tapşırıqlar
1. `app_read` (yalnız oxuma) rolu yarat, ona `SELECT` ver, yeni login istifadəçisinə həvalə et, o istifadəçi ilə qoşulub `INSERT`-in rədd edildiyini yoxla.
2. `pg_dump -Fc` ilə `shop`-u backup et, `shop_copy` adında yeni baza yarat, `pg_restore` ilə bərpa et.
3. `ALTER DEFAULT PRIVILEGES` istifadə et ki, yeni yaradılan cədvəllər avtomatik `app_read`-ə oxunsun. Yeni cədvəl yarat, yoxla.
4. `events` cədvəlini RANGE partisiyalarla qur, bir neçə ay üçün partisiya yarat, data əlavə et, `EXPLAIN` ilə partition pruning-i gör.
5. RLS ilə: müştərinin yalnız öz sifarişlərini görməsini təmin et.

---

## Faza 9 — Replikasiya, Miqyaslama və Yüksək Əlçatanlıq (EXPERT)

### 9.1 Streaming (fiziki) replikasiya

Primary WAL-ı standby-lara ötürür; standby oxu üçün istifadə oluna bilər (read replica).
```
Primary ──(WAL stream)──► Standby 1 (hot standby, oxu üçün)
         └─(WAL stream)──► Standby 2
```
- **Async** (default): primary standby-ı gözləmir → sürətli, amma failover-da az data itkisi riski.
- **Sync** (`synchronous_commit`, `synchronous_standby_names`): commit standby təsdiq edənə qədər gözləyir → sıfır itki, amma yavaş.

Qurmaq üçün əsas addımlar: primary-də `wal_level=replica`, replikasiya rolu, `pg_basebackup` ilə standby-ı yarat, `primary_conninfo` təyin et, standby-ı başlat.

### 9.2 Logical replikasiya

Cədvəl/sətir səviyyəsində, versiyalar arası, seçmə replikasiya:
```sql
-- Primary-də
CREATE PUBLICATION pub_products FOR TABLE products, categories;
-- Abunəçidə
CREATE SUBSCRIPTION sub_products
  CONNECTION 'host=primary dbname=shop user=repl'
  PUBLICATION pub_products;
```
İstifadə: versiya yüksəltmə (zero-downtime upgrade), datanı fərqli bazalara göndərmə, seçmə cədvəl replikasiyası.

### 9.3 Failover və HA alətləri

PostgreSQL öz-özünə avtomatik failover etmir — xarici alət lazımdır:
- **Patroni** — ən populyar; etcd/Consul + avtomatik lider seçimi.
- **repmgr**, **pg_auto_failover** — alternativlər.
- **Bağlantı yönləndirmə:** HAProxy / PgBouncer / DNS.

### 9.4 Read/write ayırması və miqyaslama strategiyaları
- **Şaquli:** daha güclü server (RAM/CPU/SSD).
- **Read replica-lar:** oxu yükünü paylaş (yazma yalnız primary-də).
- **Sharding:** datanı çox serverə böl (`Citus` extension) — çox böyük miqyas üçün.
- **Keşləmə:** tez-tez oxunan data üçün Redis/materialized view.

### Faza 9 — Tapşırıqlar (konseptual + praktik)
1. İki Docker PostgreSQL instansı ilə streaming replikasiya qur (primary + standby). Standby-da `pg_is_in_recovery()` `true` olduğunu yoxla. Primary-də sətir əlavə et, standby-da göründüyünü gör.
2. `synchronous_commit`-in `on`/`off`/`remote_apply` fərqlərini izah et.
3. Logical replikasiya ilə yalnız `products` cədvəlini ikinci bazaya köçür.
4. Async vs sync replikasiyanın "data itkisi vs performans" tradeoff-unu öz sözlərinlə izah et.
5. Patroni-nin failover-da rolunu təsvir et: split-brain nədir və necə qarşısı alınır?

---

## Faza 10 — Daxili Quruluş (Internals) və Extension-lar (EXPERT)

### 10.1 Fiziki saxlanma: heap, səhifə, tuple

- Data **8KB səhifələrdə** (page) saxlanır. Hər səhifədə sətirlər (tuple) + başlıq + item pointer-lər.
- Hər tuple-də sistem sütunları: `xmin` (yaradan tranzaksiya), `xmax` (silən), `ctid` (fiziki yer).
- Sətri fiziki yeri ilə görmək: `SELECT ctid, * FROM products LIMIT 3;`

### 10.2 TOAST — böyük dəyərlərin saxlanması

Səhifəyə sığmayan böyük sütunlar (uzun `text`, `jsonb`, `bytea`) avtomatik sıxılır və ayrıca TOAST cədvəlinə köçürülür. Bu, şəffaf baş verir. `pg_relation_size` vs `pg_total_relation_size` fərqi burdadır.

### 10.3 WAL internals

- Hər dəyişiklik əvvəl WAL-a yazılır (durability). WAL **segmentlərə** bölünür (default 16MB).
- **Checkpoint** — kirli səhifələri diskə yazır, WAL-ı azad edir. `checkpoint_timeout`, `max_wal_size` tənzimlənir.
- `pg_current_wal_lsn()` — hazırkı WAL mövqeyi (LSN). Replikasiya lag-ını LSN fərqi ilə ölçürlər.

### 10.4 Planner və cost model

Planner mümkün planlar arasından ən aşağı **cost**-lu olanı seçir. Cost = `seq_page_cost`, `random_page_cost`, `cpu_tuple_cost` və s. əsasında hesablanır. Statistika (`pg_statistic`, `pg_stats`) sətir sayı/seçicilik təxminləri verir.

```sql
SELECT * FROM pg_stats WHERE tablename='orders' AND attname='status';
-- most_common_vals, histogram_bounds, n_distinct, correlation göstərir
```

### 10.5 Faydalı sistem kataloqları və görünüşlər
```sql
pg_class        -- cədvəllər/indekslər
pg_attribute    -- sütunlar
pg_index        -- indekslər
pg_stat_activity-- aktiv sessiyalar
pg_locks        -- cari kilidlər
pg_stat_user_tables, pg_statio_user_tables -- I/O statistikası
SELECT pg_size_pretty(pg_total_relation_size('orders'));  -- cədvəl ölçüsü
```

### 10.6 Vacib extension-lar
```sql
CREATE EXTENSION pg_stat_statements;  -- sorğu statistikası (mütləq)
CREATE EXTENSION pg_trgm;             -- fuzzy/ILIKE axtarış
CREATE EXTENSION postgis;             -- coğrafi/məkan datası (GIS)
CREATE EXTENSION hstore;              -- açar-dəyər
CREATE EXTENSION uuid_ossp;           -- UUID generatoru
CREATE EXTENSION pgcrypto;            -- şifrələmə/hashing
-- Xarici: Citus (sharding), TimescaleDB (zaman seriyaları),
--         pg_partman (partisiya), pgvector (AI embedding axtarışı)
SELECT * FROM pg_available_extensions ORDER BY name;
```

### Faza 10 — Tapşırıqlar
1. `SELECT ctid, xmin, xmax, * FROM products LIMIT 5;` işlət. Bir sətri UPDATE et, `ctid`-in dəyişdiyini gör (yeni versiya = yeni fiziki yer).
2. `pg_total_relation_size` vs `pg_relation_size` fərqini bir cədvəldə göstər (indeks + TOAST payı).
3. `pg_stats`-də `orders.status` sütununun `most_common_vals`-una bax. Planner bu məlumatı necə istifadə edir?
4. `pg_current_wal_lsn()`-ı oxu, bir neçə INSERT et, yenidən oxu — LSN irəlilədimi?
5. `pgcrypto` ilə parol hash-lə (`crypt`, `gen_salt('bf')`) və yoxla.

---

## Yekun Layihə — Expert Səviyyəni Sübut Et

Aşağıdakıları vahid bir sistemdə birləşdir:

1. **Sxem:** Onlayn mağazanı genişləndir — `payments`, `shipments`, `reviews` cədvəlləri əlavə et; uyğun constraint və foreign key-lər.
2. **İndeksləmə:** ən çox işlədəcəyin 5 sorğunu müəyyən et, hər biri üçün optimal indeks seç (partial/expression/covering daxil olmaqla), `EXPLAIN ANALYZE` ilə əsaslandır.
3. **Partisiyalama:** `orders`-i vaxt üzrə partisiyala, ən azı 3 aylıq partisiya yarat, partition pruning-i sübut et.
4. **Analitika:** window funksiyaları ilə "hər müştərinin aylıq xərci və əvvəlki aya nisbətdə artımı" hesabatını qur; materialized view kimi saxla və `CONCURRENTLY` refresh et.
5. **Proqram məntiqi:** stok idarəsi üçün trigger + `FOR UPDATE` ilə yarış vəziyyətindən (race condition) qorunan "sifariş ver" funksiyası yaz.
6. **Təhlükəsizlik:** `readonly_user`, `app_user`, `admin` rolları yarat; RLS ilə müştərini öz datası ilə məhdudlaşdır.
7. **Etibarlılıq:** `pg_dump` ilə backup skripti yaz; PITR strategiyasını (nə arxivlənir, necə bərpa olunur) sənədləşdir.
8. **Performans hesabatı:** `pg_stat_statements` ilə ən bahalı 5 sorğunu tap, hər birini optimallaşdır, əvvəl/sonra vaxtları göstər.
9. **Konkurentlik testi:** iki paralel tranzaksiya ilə stok azaltmanı test et, `SERIALIZABLE` + retry ilə düzgünlüyü təmin et.

Bunları bir `README.md` + SQL fayllarında sənədləşdirsən — bu, real portfelə çevrilir.

---

## Öyrənmə xəritəsi və resurslar

**Tövsiyə olunan ardıcıllıq və vaxt (gündə 1-2 saat işlə):**
- Həftə 1-2: Faza 0-1 (təməl möhkəm olsun)
- Həftə 3-4: Faza 2 (JOIN + window funksiyaları — çox məşq et)
- Həftə 5: Faza 3 (JSONB, array, FTS)
- Həftə 6: Faza 4 (indekslər — hər növü sına)
- Həftə 7-8: Faza 5 (EXPLAIN oxumağı avtomatizmə çatdır — bu, seni fərqləndirəcək)
- Həftə 9: Faza 6 (PL/pgSQL, trigger)
- Həftə 10: Faza 7 (MVCC, izolyasiya — iki sessiya ilə çox eksperiment et)
- Həftə 11-12: Faza 8 (administrasiya, backup, partisiya)
- Həftə 13: Faza 9-10 (replikasiya, internals)
- Həftə 14-16: Yekun layihə

**Əsas resurslar:**
- Rəsmi sənədləşmə (postgresql.org/docs) — dünyanın ən yaxşı DB sənədlərindən biridir, mütləq oxu.
- `psql`-də `\h КОМАНДА` və `\?` — daxili köməkçi.
- `EXPLAIN` planlarını vizuallaşdırmaq üçün onlayn izahedici alətlər.
- Öz "lab" bazanı həmişə əlində saxla və hər yeni öyrəndiyini orada sına.

**Expert olmağın əsl əlaməti:** yeni bir sorğu yavaş işləyəndə `EXPLAIN (ANALYZE, BUFFERS)`-a baxıb səbəbi (indeks yoxdur? statistika köhnədir? pis JOIN sırası? bloat?) dəqiqliklə deyə bilmək və düzəltmək. Bu bacarığı Faza 5 və 7-də qazanırsan — ona ən çox vaxt ayır.

Uğurlar! 🐘
