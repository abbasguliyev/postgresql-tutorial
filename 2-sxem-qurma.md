# `shop` Sxemini Qurma — Addım-addım Qeydlər

> Bu fayl, əsas kursun ("Kurs boyu istifadə edəcəyimiz nümunə sxem" bölməsi) tətbiqi zamanı çəkdiyimiz addımların, etdiyimiz səhvlərin və öyrəndiyimiz nüansların **toplu qeydidir**. Məqsəd: sxemi unutsan, buraya baxıb sürətlə yadına sala biləsən.

---

## 1. `customers`

```sql
CREATE TABLE customers (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   text NOT NULL,
    email       text NOT NULL UNIQUE,
    country     text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);
```
- `bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` — avtomatik artan, ilkin açar (köhnə `serial`-ın müasir əvəzi).
- `email ... UNIQUE` — iki müştəri eyni email-lə qeydiyyatdan keçə bilməz, baza bunu məcbur edir.
- `timestamptz` — vaxt üçün həmişə bu, `timestamp` yox (zaman qurşağı fərqlərindən qorunmaq üçün).

---

## 2. `categories`

```sql
CREATE TABLE categories (
    id      int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    text NOT NULL UNIQUE
);
```

**Tutduğumuz səhv:** ilk cəhddə `UNIQUE`-i unutmuşduq (`name text NOT NULL` yazmışdıq). Nəticə: iki eyni adlı kateqoriya yaratmaq mümkün olardı, bu da mənasız təkrarçılığa yol açardı. Cədvəl hələ boş olduğu üçün ən sadə həll: `DROP TABLE` edib düzgün versiya ilə yenidən yaratmaq (`ALTER TABLE ... ADD CONSTRAINT` da mümkündür, amma bu, sonrakı fazanın mövzusudur).

---

## 3. `products`

```sql
CREATE TABLE products (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL,
    category_id  int REFERENCES categories(id),
    price        numeric(10,2) NOT NULL CHECK (price >= 0),
    stock        int NOT NULL DEFAULT 0 CHECK (stock >= 0),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);
```
- `category_id int REFERENCES categories(id)` — xarici açar (foreign key), `NOT NULL` yazılmayıb → kateqoriyasız məhsul ola bilər.
- `numeric(10,2)` — pul üçün **həmişə `numeric`**, `float` yox (`0.1+0.2≠0.3` problemi).
- `CHECK (price >= 0)`, `CHECK (stock >= 0)` — mənfi qiymət/stok qadağandır, baza səviyyəsində.
- `jsonb NOT NULL DEFAULT '{}'::jsonb` — dəyişkən, sərbəst-formalı əlavə məlumat üçün (rəng, çəki və s. — hər məhsulda fərqli ola bilər). `'{}'` boş JSON obyektinin mətn forması, `::jsonb` onu `jsonb` tipinə çevirən cast-dır.

### `jsonb` — qısa xatırlatma
- `jsonb` — binar, indekslənə bilən JSON (adi `json`-dan sürətli, demək olar həmişə bunu işlət).
- Oxumaq: `attributes ->> 'color'` (text qaytarır) ən çox işlənən formadır. `attributes -> 'color'` (jsonb qaytarır) yalnız **iç-içə** JSON-un içinə "addım-addım getmək" üçün lazımdır — zəncirin **son** addımında `->>`, əvvəlki addımlarda `->`.
- Yazmaq: `'{"color":"red"}'::jsonb` (birbaşa mətn+cast) və ya `jsonb_build_object('color','red')` (funksiya ilə) — ikisi eyni nəticəni verir.

---

## 4. `orders`

```sql
CREATE TABLE orders (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customers(id),
    status       text NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','paid','shipped','delivered','cancelled')),
    created_at   timestamptz NOT NULL DEFAULT now()
);
```

**Tutduğumuz səhv:** ilk cəhddə `created_at timestamptz DEFAULT now()` yazılmışdı, `NOT NULL` unudulmuşdu. Fərq: `DEFAULT` yalnız **dəyər verilmədikdə** işə düşür — kimsə bilərəkdən `NULL` yazsa, `DEFAULT` bunun qarşısını almır. `NOT NULL` əlavə etməklə bu tamam bağlanır.

**Sütun məhdudiyyətlərinin sırası əhəmiyyətlidirmi?** Xeyr — `NOT NULL`, `DEFAULT`, `REFERENCES`, `CHECK` kimi məhdudiyyətləri istənilən sırayla yaza bilərsən, funksional fərq yoxdur. Sıra sadəcə oxunaqlılıq zövqüdür.

**`REFERENCES` üçün `ON DELETE` yazılmayanda nə olur?** Defolt — `NO ACTION`: əlaqəli sətir varkən silməyə **icazə verilmir**, xəta qaytarılır. Bu, təhlükəsiz defoltdur — silinməsi lazım olan əlaqəli data varsa, səni "bilərəkdən qərar ver" məcburiyyətinə salır.

---

## 5. `order_items` — many-to-many "körpü" cədvəli

```sql
CREATE TABLE order_items (
    order_id    bigint NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id  bigint NOT NULL REFERENCES products(id),
    quantity    int NOT NULL CHECK (quantity > 0),
    unit_price  numeric(10,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);
```

- **Many-to-many:** bir sifarişdə çox məhsul, bir məhsul çox sifarişdə ola bilər — bunları birbaşa bağlamaq mümkün olmadığı üçün aralarında bu "körpü" cədvəl var, hər sətri "bu sifarişdə, bu məhsuldan, bu qədər" mənasını daşıyır.
- **`ON DELETE CASCADE`** məhz burada işlədilir (digər FK-lərdən fərqli olaraq): sifariş silinəndə, onun sətirləri **mənasızlaşır**, ona görə avtomatik silinmələri məntiqlidir. Kateqoriya/məhsul kimi digər əlaqələrdə isə avtomatik silmək təhlükəli olardı (gözlənilməz data itkisi) — ona görə orda defolt (`NO ACTION`) saxlanılıb.
- **`PRIMARY KEY (order_id, product_id)`** — kompozit (iki-sütunlu) ilkin açar, sütun siyahısından **sonra**, ayrıca sətir kimi yazılır. Bunsuz eyni sifarişdə eyni məhsul təkrarlana bilərdi.

**Tutduğumuz səhv:** ilk cəhddə `PRIMARY KEY` sətri tamam unudulmuşdu — nəticədə cədvəlin heç ilkin açarı olmurdu.

---

## 6. Test datası — işlətdiyimiz INSERT-lər

Cədvəlləri yaratdıqdan sonra, bunları icra edərək doldurduq (sıra vacibdir — foreign key-lər səbəbindən əvvəlcə `categories`/`customers`/`products`, sonra `orders`, ən sonda `order_items`):

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

-- hər sifarişə 1-4 məhsul (təsadüfi seçilmiş, təkrarsız)
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

> `order_items`-dəki `CROSS JOIN LATERAL` və `DISTINCT ON` hələ dərinləşdirilməyib (bunlar Faza 2-nin JOIN/subquery mövzusudur) — hazırda sadəcə "hər sifarişə təsadüfi 3 məhsul bağlayır" kimi qəbul et, Faza 2-də geri qayıdıb sətir-sətir söküb izah edəcəyik.

### INSERT-lərdə işlənən SQL mexanizmləri

Bu izahların tam versiyası əsas kurs faylında (`postgresql-expert-kurs.md`, "Kurs boyu istifadə edəcəyimiz nümunə sxem" bölməsi) da var — bura qısa, təkrar xatırlatma üçün.

**`||` — mətn birləşdirmə:**
```sql
'Customer ' || g          -- g=5 üçün: 'Customer 5'
'user' || g || '@example.com'   -- 'user5@example.com'
```

**Massiv indeksi (1-dən başlayır!):**
```sql
(ARRAY['AZ','TR','US','DE','GB'])[1 + (g % 5)]
```
`%` = qalıq (modulo). `g % 5` → `0-4`, `+1` → `1-5` (massiv indeksi). `g` artdıqca `AZ→TR→US→DE→GB` dövrü təkrarlanır. **Deterministikdir** (`random()`-dan fərqli olaraq hər işlətmədə eyni nəticə).

**`random()`:**
```sql
random() * 490 + 10   -- 10-500 arası təsadüfi ədəd
```
`random()` özü `0` (daxil) — `1` (xaric) arası qaytarır; vurma/toplama ilə istədiyin diapazona köçürürsən.

**`::` — cast (tip çevrilməsi):**
```sql
'123'::int                          -- eynidir: CAST('123' AS int)
(random() * 490 + 10)::numeric      -- float → numeric (round() üçün, pul dəqiqliyi)
(random() * 200)::int               -- float → int (YAXIN tam ədədə yuvarlaqlaşdırır, KƏSMİR)
```

**`ANALYZE`:**
Cədvəli skan edib statistika toplayır (neçə fərqli dəyər, paylanma, təxmini sətir sayı) — sorğu planlaşdırıcısı (query planner) bu statistikaya əsasən "indeks işlədim, yoxsa bütün cədvəli oxuyum?" qərarını verir. Böyük data əlavə etdikdən sonra mütləq işlədilməlidir ki, köhnəlmiş statistika səhv qərarlara səbəb olmasın. Dərinliyi: Faza 5.

---

*Əlaqəli fayllar: `postgresql-expert-kurs.md` (əsas kurs), `1-giris.md` (daxili mexanizmlər — WAL, MVCC, proseslər).*
