-- FitRoom - esquema actual consolidado
-- Motor: MySQL 8.0 / InnoDB / utf8mb4
--
-- Este archivo representa la estructura final resultante de las migraciones
-- Flyway V202403121600 a V202403121677. Es para crear una base nueva.
-- Para una instalación normal se recomienda dejar que Spring/Flyway ejecute
-- las migraciones de db/migration y com/fitroom/gym/db/migration.

CREATE DATABASE IF NOT EXISTS fitroom
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE fitroom;

SET NAMES utf8mb4;

CREATE TABLE users (
    id INT NOT NULL AUTO_INCREMENT,
    username VARCHAR(36) NOT NULL,
    password VARCHAR(100) NOT NULL,
    user_role VARCHAR(20) NOT NULL,
    created_by VARCHAR(36) NOT NULL,
    enabled BOOLEAN NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY username_uk (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE states (
    id BIGINT NOT NULL AUTO_INCREMENT,
    code VARCHAR(3) NOT NULL,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cities (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    state_id BIGINT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_city_state FOREIGN KEY (state_id) REFERENCES states(id),
    INDEX idx_cities_state_id (state_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE colonias (
    id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    normalized_name VARCHAR(255) GENERATED ALWAYS AS (LOWER(name)) STORED,
    zip_code VARCHAR(10),
    city_id BIGINT NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_colonias_city FOREIGN KEY (city_id)
        REFERENCES cities(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    UNIQUE KEY ux_colonias_city_normalized_name (city_id, normalized_name),
    INDEX idx_colonias_city_id (city_id),
    INDEX idx_colonias_city_zip (city_id, zip_code),
    FULLTEXT KEY ft_colonias_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE members (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    last_names VARCHAR(150) NOT NULL,
    cell_phone VARCHAR(10) NOT NULL,
    email VARCHAR(100) UNIQUE,
    birthdate DATE,
    address VARCHAR(150),
    emergency_phone VARCHAR(10),
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_favorite BOOLEAN DEFAULT FALSE,
    emergency_relation VARCHAR(50),
    city_id BIGINT,
    colonia_id BIGINT,
    medical_conditions TEXT,
    created_by VARCHAR(50),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (id),
    UNIQUE KEY uq_members_cell_phone (cell_phone),
    CONSTRAINT fk_member_city FOREIGN KEY (city_id) REFERENCES cities(id),
    CONSTRAINT fk_members_colonia FOREIGN KEY (colonia_id)
        REFERENCES colonias(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_members_colonia_id (colonia_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE membership_config (
    id INT NOT NULL AUTO_INCREMENT,
    days_number INT NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_grace_period INT,
    one_time_payment BOOLEAN NOT NULL DEFAULT FALSE,
    rate_id INT,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rates (
    id INT NOT NULL AUTO_INCREMENT,
    days_number INT NOT NULL,
    concept VARCHAR(150) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    enabled BOOLEAN NOT NULL,
    username VARCHAR(36) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    period_type VARCHAR(50) NOT NULL,
    is_favorite TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE membership_config
    ADD CONSTRAINT fk_membership_config_rate
    FOREIGN KEY (rate_id) REFERENCES rates(id);

CREATE TABLE rates_table_history (
    id INT NOT NULL AUTO_INCREMENT,
    value_changed VARCHAR(150) NOT NULL,
    rate_id INT NOT NULL,
    username VARCHAR(36) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_rates_history_rate FOREIGN KEY (rate_id) REFERENCES rates(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE work_shifts (
    id INT NOT NULL AUTO_INCREMENT,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    entry_amount DECIMAL(10,2) NOT NULL,
    responsible_user VARCHAR(50) NOT NULL,
    opening_reviewer_admin_user VARCHAR(50) NOT NULL,
    closing_reviewer_admin_user VARCHAR(50),
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE work_shifts_notes (
    id INT NOT NULL AUTO_INCREMENT,
    work_shift_id INT NOT NULL,
    username VARCHAR(36) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comments VARCHAR(150) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_work_shifts_notes_shift FOREIGN KEY (work_shift_id)
        REFERENCES work_shifts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE debit_transactions (
    id INT NOT NULL AUTO_INCREMENT,
    concept VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    work_shift_id INT NOT NULL,
    username VARCHAR(36) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comments VARCHAR(150),
    is_cancelled BOOLEAN DEFAULT 0,
    admin_user_cancellation_approval VARCHAR(36),
    PRIMARY KEY (id),
    CONSTRAINT fk_debit_transactions_shift FOREIGN KEY (work_shift_id)
        REFERENCES work_shifts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE member_membership (
    id INT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    debit_transaction_id INT NOT NULL,
    membership_config_id INT NOT NULL,
    expiration_date TIMESTAMP NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(36) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT fk_member_membership_member FOREIGN KEY (member_id) REFERENCES members(id),
    CONSTRAINT fk_member_membership_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subscriptions (
    id INT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    debit_transaction_id INT NOT NULL,
    member_membership_id INT,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(36) NOT NULL,
    period_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'EXPIRED',
    rate_id INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_subscriptions_member FOREIGN KEY (member_id) REFERENCES members(id),
    CONSTRAINT fk_subscriptions_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    INDEX idx_subscriptions_rate_id (rate_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE check_in (
    id INT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(36) NOT NULL,
    status VARCHAR(50),
    PRIMARY KEY (id),
    UNIQUE KEY uq_check_in_register_timestamp (register_timestamp),
    CONSTRAINT fk_check_in_member FOREIGN KEY (member_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE check_out (
    id INT NOT NULL AUTO_INCREMENT,
    check_in_id INT NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(36) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_check_out_check_in_id (check_in_id),
    CONSTRAINT fk_check_out_check_in FOREIGN KEY (check_in_id) REFERENCES check_in(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE articles (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sale_price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL,
    status TINYINT(1) NOT NULL DEFAULT 1,
    expiration_date TIMESTAMP NULL DEFAULT NULL,
    username VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE inventory (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    article_id INT NOT NULL,
    previous_quantity INT NOT NULL,
    current_quantity INT NOT NULL,
    description TEXT,
    register_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100),
    CONSTRAINT fk_inventory_article FOREIGN KEY (article_id) REFERENCES articles(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sale (
    id INT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    is_pending_payment BOOLEAN,
    is_cancelled BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    username VARCHAR(100),
    PRIMARY KEY (id),
    CONSTRAINT fk_sale_member FOREIGN KEY (member_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_articles (
    id INT NOT NULL AUTO_INCREMENT,
    article_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_sale DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    sale_id INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_sales_articles_article FOREIGN KEY (article_id) REFERENCES articles(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sales_articles_sale FOREIGN KEY (sale_id) REFERENCES sale(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_details (
    id INT NOT NULL AUTO_INCREMENT,
    debit_transaction_id INT NOT NULL,
    sale_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_sales_details_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    CONSTRAINT fk_sales_details_sale FOREIGN KEY (sale_id) REFERENCES sale(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cancellations (
    id INT NOT NULL AUTO_INCREMENT,
    debit_transaction_id INT NOT NULL UNIQUE,
    cancellation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    cancelled_by_user VARCHAR(50) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_cancellations_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase (
    id INT NOT NULL AUTO_INCREMENT,
    supplier TEXT,
    username VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase_details (
    id INT NOT NULL AUTO_INCREMENT,
    article_id INT NOT NULL,
    purchase_id INT NOT NULL,
    quantity INT NOT NULL,
    purchase_price INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_purchase_details_purchase FOREIGN KEY (purchase_id) REFERENCES purchase(id),
    CONSTRAINT fk_purchase_details_article FOREIGN KEY (article_id) REFERENCES articles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gym_profile (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    facebook_url VARCHAR(255),
    instagram_url VARCHAR(255),
    twitter_url VARCHAR(255),
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    logo_url VARCHAR(512),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gym_config (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gym_config_history (
    id INT NOT NULL AUTO_INCREMENT,
    gym_config_id INT UNSIGNED NOT NULL,
    description VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_gym_config FOREIGN KEY (gym_config_id) REFERENCES gym_config(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE invalid_check_ins (
    id INT NOT NULL AUTO_INCREMENT,
    input_value VARCHAR(255),
    username VARCHAR(100),
    register_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subscription_history (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    subscription_id INT NOT NULL,
    description VARCHAR(250) NOT NULL,
    notes VARCHAR(250),
    username VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    action_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_subscription_history_subscription FOREIGN KEY (subscription_id)
        REFERENCES subscriptions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE courtesies (
    id INT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    register_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    concept VARCHAR(100) NOT NULL,
    notes TEXT,
    status VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL,
    cancelled_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_courtesies_member FOREIGN KEY (member_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE checkin_subscription (
    id INT NOT NULL AUTO_INCREMENT,
    checkin_id INT NOT NULL,
    subscription_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_checkin_subscription_checkin FOREIGN KEY (checkin_id) REFERENCES check_in(id),
    CONSTRAINT fk_checkin_subscription_subscription FOREIGN KEY (subscription_id)
        REFERENCES subscriptions(id),
    CONSTRAINT uq_checkin_subscription UNIQUE (checkin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE checkin_courtesy (
    id INT NOT NULL AUTO_INCREMENT,
    checkin_id INT NOT NULL,
    courtesy_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_checkin_courtesy_checkin FOREIGN KEY (checkin_id) REFERENCES check_in(id),
    CONSTRAINT fk_checkin_courtesy_courtesy FOREIGN KEY (courtesy_id) REFERENCES courtesies(id),
    CONSTRAINT uq_checkin_courtesy UNIQUE (checkin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE member_fingerprint_templates (
    id BIGINT NOT NULL AUTO_INCREMENT,
    member_id INT NOT NULL,
    template BLOB NOT NULL,
    created_by VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_member_fingerprint_member FOREIGN KEY (member_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rate_allowed_methods (
    rate_id INT NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (rate_id, payment_method),
    CONSTRAINT fk_rate_allowed_methods_rate FOREIGN KEY (rate_id) REFERENCES rates(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE courtesy_history (
    id INT NOT NULL AUTO_INCREMENT,
    description VARCHAR(300) NOT NULL,
    courtesy_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action_type VARCHAR(20) NOT NULL,
    notes VARCHAR(250),
    PRIMARY KEY (id),
    CONSTRAINT fk_courtesy_history_courtesy FOREIGN KEY (courtesy_id)
        REFERENCES courtesies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE member_status (
    member_id INT NOT NULL,
    status VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL,
    entity_id INT,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id),
    CONSTRAINT fk_member_status_member FOREIGN KEY (member_id)
        REFERENCES members(id) ON DELETE CASCADE,
    INDEX idx_member_status_status (status),
    INDEX idx_member_status_entity_id (entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE OR REPLACE VIEW vw_member_today_status AS
SELECT c.member_id,
       'COURTESY' AS source_type,
       c.id AS source_entity_id,
       CASE
           WHEN c.status = 'CANCELED' OR CURRENT_DATE NOT BETWEEN c.start_date AND c.end_date THEN 'NONE'
           WHEN c.type = 'SESSION' THEN 'SESSION'
           WHEN c.end_date = CURRENT_DATE THEN 'EXPIRED'
           WHEN c.status = 'EXPIRING_SOON' AND EXISTS (
               SELECT 1 FROM subscriptions renewal
               WHERE renewal.member_id = c.member_id
                 AND renewal.status = 'PROGRAMMED'
                 AND renewal.period_type <> 'SESSION'
                 AND DATE(renewal.start_date) <= DATE_ADD(c.end_date, INTERVAL 1 DAY)
                 AND DATE(renewal.end_date) >= c.end_date
           ) THEN 'ACTIVE'
           WHEN c.status = 'EXPIRING_SOON' THEN 'EXPIRING_SOON'
           WHEN c.status = 'ACTIVE' THEN 'ACTIVE'
           ELSE 'NONE'
       END AS status,
       IF(c.status <> 'CANCELED' AND CURRENT_DATE BETWEEN c.start_date AND c.end_date,
          'COURTESY', 'NONE') AS type,
       IF(c.status <> 'CANCELED' AND CURRENT_DATE BETWEEN c.start_date AND c.end_date,
          c.id, NULL) AS entity_id
FROM courtesies c
UNION ALL
SELECT s.member_id,
       'SUBSCRIPTION' AS source_type,
       s.id AS source_entity_id,
       CASE
           WHEN s.status IN ('CANCELED', 'PROGRAMMED')
                OR CURRENT_DATE NOT BETWEEN DATE(s.start_date) AND DATE(s.end_date) THEN 'NONE'
           WHEN s.period_type = 'SESSION' THEN 'SESSION'
           WHEN DATE(s.end_date) = CURRENT_DATE THEN 'EXPIRED'
           WHEN s.status = 'EXPIRING_SOON' AND EXISTS (
               SELECT 1 FROM subscriptions renewal
               WHERE renewal.member_id = s.member_id
                 AND renewal.id <> s.id
                 AND renewal.status = 'PROGRAMMED'
                 AND renewal.period_type <> 'SESSION'
                 AND s.period_type <> 'SESSION'
                 AND DATE(renewal.start_date) <= DATE_ADD(DATE(s.end_date), INTERVAL 1 DAY)
                 AND DATE(renewal.end_date) >= DATE(s.end_date)
           ) THEN 'ACTIVE'
           WHEN s.status = 'EXPIRING_SOON' THEN 'EXPIRING_SOON'
           ELSE 'ACTIVE'
       END AS status,
       IF(s.status NOT IN ('CANCELED', 'PROGRAMMED')
              AND CURRENT_DATE BETWEEN DATE(s.start_date) AND DATE(s.end_date),
          'SUBSCRIPTION', 'NONE') AS type,
       IF(s.status NOT IN ('CANCELED', 'PROGRAMMED')
              AND CURRENT_DATE BETWEEN DATE(s.start_date) AND DATE(s.end_date),
          s.id, NULL) AS entity_id
FROM subscriptions s;

-- Datos base que el sistema espera en una instalación nueva.
INSERT INTO states (code, name) VALUES ('VER', 'Veracruz');

INSERT INTO gym_config (name, type, is_enabled) VALUES
    ('Number Pad', 'DEVICE', 0),
    ('Fingerprint', 'DEVICE', 0),
    ('Hola!', 'GREETING', 1),
    ('CASH', 'PAYMENT_METHOD', 1),
    ('CARD', 'PAYMENT_METHOD', 1),
    ('TRANSFER', 'PAYMENT_METHOD', 1),
    ('dashboard', 'PAGE', 0),
    ('calendar', 'PAGE', 0);

INSERT INTO gym_profile (name) VALUES ('Gym');

INSERT INTO members (
    name, last_names, cell_phone, is_favorite, is_internal
) VALUES ('Público ', 'en General', '1111111111', FALSE, TRUE);

INSERT INTO members (
    name, last_names, cell_phone, is_favorite, is_internal
) VALUES ('Visita', 'público general', 'WALK_IN', FALSE, TRUE);

INSERT INTO users (
    username, password, user_role, created_by, enabled
) VALUES (
    'CHECKIN_GYM',
    '$2a$10$qg8IYb/KntLkHjSMs9cXaObbmQGHUwRzpOAioD9NutGuzTHItZNtC',
    'REGISTRATION',
    'SYSTEM',
    TRUE
);

-- El administrador AHURI_ADMIN se crea al iniciar Spring Boot mediante
-- DefaultAdminInitializer usando DEFAULT_ADMIN_PASSWORD_HASH.
