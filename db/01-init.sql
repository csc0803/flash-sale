CREATE DATABASE IF NOT EXISTS flashsaledb
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

USE flashsaledb;
DROP TABLE IF EXISTS orders, product, users;

CREATE TABLE IF NOT EXISTS users(
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	username VARCHAR(100) NOT NULL,
	password_hash VARCHAR(100) NOT NULL ,
    role VARCHAR(20)  NOT NULL DEFAULT 'USER',
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uk_users_username UNIQUE (username),
    CONSTRAINT ck_users_role CHECK (role IN ('USER', 'ADMIN'))
);

CREATE TABLE IF NOT EXISTS product(
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	name VARCHAR(100) NOT NULL,
	price BIGINT NOT NULL COMMENT '新台幣，整數',
    stock INT DEFAULT 0 NOT NULL,
    version BIGINT DEFAULT 0 NOT NULL,
	sale_start_at DATETIME NOT NULL,
    sale_end_at DATETIME NOT NULL,
    CONSTRAINT ck_product_stock CHECK (stock >= 0),
    CONSTRAINT ck_product_price CHECK (price >= 0),
    CONSTRAINT ck_product_sale_time CHECK (sale_end_at > sale_start_at)
);

CREATE TABLE IF NOT EXISTS orders(
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	order_no VARCHAR(32) NOT NULL,
	user_id BIGINT NOT NULL ,
    product_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    paid_at DATETIME NULL,
    CONSTRAINT uk_orders_order_no UNIQUE (order_no),
    CONSTRAINT uk_orders_user_product UNIQUE (user_id, product_id),
    CONSTRAINT ck_orders_status CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES product (id)
);

