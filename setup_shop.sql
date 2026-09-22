-- Kurs boyu istifadə edəcəyimiz nümunə sxem (onlayn mağaza) + test datası.
-- İstifadə: psql-də \c shop , sonra \i setup_shop.sql

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

ANALYZE;
