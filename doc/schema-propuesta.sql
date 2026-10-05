-- =====================================================================
-- FitRoom SaaS - ESQUEMA PROPUESTO (multi-centro)
-- Motor: MySQL 8.0 / InnoDB / utf8mb4
--
-- ESTATUS: PROPUESTA PRELIMINAR para revisión del cliente.
-- NO es una migración ejecutable: las migraciones Flyway reales
-- (convención VYYYYMMDDHHmm) se generarán a partir de este archivo una
-- vez aprobado. Las líneas nuevas/cambiadas llevan anotación [NUEVO],
-- [CAMBIO] o [PROVISIONAL] (dependen de preguntas abiertas, ver
-- doc/preguntas-y-respuestas.md).
--
-- Base: schema.sql (esquema actual consolidado V202403121600-V202403121677)
-- Cambios conforme a ADR-0001 … ADR-0010 (incluye sucursales, ADR-0010).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS fitroom
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE fitroom;

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- Catálogos geográficos compartidos (SIN centro, ADR-0001) — sin cambios
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- [NUEVO] Centros (ADR-0002). Raíz del multi-tenancy: toda tabla
-- operativa referencia a centers.id internamente; center_uuid es el
-- único identificador expuesto hacia clientes/integraciones (y en el JWT).
-- ---------------------------------------------------------------------

CREATE TABLE centers (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    center_uuid  BINARY(16)   NOT NULL,
    name         VARCHAR(255) NOT NULL,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_centers_uuid (center_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [NUEVO] Sucursales (ADR-0010): 1 centro → N sucursales.
-- Sub-división interna del centro (nunca un tenant). SOLO desactivación
-- lógica: no hay borrado físico, para que la contabilidad histórica y las
-- FK financieras sobrevivan intactas aunque la sucursal se "elimine".
-- ---------------------------------------------------------------------

CREATE TABLE branches (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    branch_uuid  BINARY(16)   NOT NULL,
    center_id    INT UNSIGNED NOT NULL,
    name         VARCHAR(255) NOT NULL,
    active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY ux_branches_uuid (branch_uuid),
    -- [NUEVO] Permite FK compuesta (branch_id, center_id) -> branches(id, center_id)
    -- en toda tabla con sucursal: garantiza que la sucursal referenciada
    -- pertenezca al mismo centro de la fila (invariante centro↔sucursal).
    UNIQUE KEY ux_branches_id_center (id, center_id),
    CONSTRAINT fk_branches_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_branches_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] users: + center_id (ADR-0003). NULL = superadministrador.
-- + branch_id (ADR-0010): obligatorio para STAFF/REGISTRATION/quiosco;
-- NULL para ADMIN/CENTER_ADMIN (ámbito de todo su centro) y SUPERADMIN.
-- username ES el correo electrónico (P-01): se amplía de VARCHAR(36),
-- insuficiente para correos reales, a VARCHAR(100).
-- user_role pasa a: SUPERADMIN, CENTER_ADMIN, ADMIN, STAFF, REGISTRATION
-- (USER renombrado a STAFF, P-06).
-- NOTA: las columnas de auditoría `username` / `created_by` del resto de
-- tablas deben normalizarse también a VARCHAR(100) en las migraciones.
-- ---------------------------------------------------------------------

CREATE TABLE users (
    id INT NOT NULL AUTO_INCREMENT,
    username VARCHAR(100) NOT NULL,                    -- [CAMBIO] era VARCHAR(36); ahora es el correo (P-01)
    password VARCHAR(100) NOT NULL,
    user_role VARCHAR(20) NOT NULL,                    -- [CAMBIO] valores: SUPERADMIN|CENTER_ADMIN|ADMIN|STAFF|REGISTRATION (P-06)
    center_id INT UNSIGNED NULL,                       -- [NUEVO] NULL = superadministrador (ADR-0003)
    branch_id INT UNSIGNED NULL,                       -- [NUEVO] sucursal del staff (ADR-0010)
    created_by VARCHAR(100) NOT NULL,                  -- [CAMBIO] era VARCHAR(36)
    enabled BOOLEAN NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY username_uk (username),
    CONSTRAINT fk_users_center FOREIGN KEY (center_id) REFERENCES centers(id),
    -- FK compuesta: si hay sucursal, debe pertenecer al centro del usuario
    -- (con branch_id NULL la FK compuesta no se evalúa; rige fk_users_center).
    CONSTRAINT fk_users_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    INDEX idx_users_center_id (center_id),
    INDEX idx_users_branch_id (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [NUEVO] Auditoría del sistema (ADR-0003, ST-003): impersonación y
-- acciones de superadmin. No audita CRUD operativo (eso vive en *_history).
-- ---------------------------------------------------------------------

CREATE TABLE audit_log (
    id BIGINT NOT NULL AUTO_INCREMENT,
    actor_username VARCHAR(100) NOT NULL,   -- superadmin que actúa
    center_id INT UNSIGNED NULL,            -- centro afectado (NULL si no aplica)
    action VARCHAR(50) NOT NULL,            -- IMPERSONATION_START|END, CENTER_CREATED, CENTER_DISABLED, USER_CREATED, USER_ROLE_CHANGED, ...
    target TEXT,                            -- detalle (JSON) del objetivo de la acción
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_audit_log_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_audit_log_center_id (center_id),
    INDEX idx_audit_log_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Socios: + center_id; llaves únicas pasan a compuestas por
-- centro (ADR-0005): (center_id, cell_phone) y (center_id, email).
-- La misma persona puede ser socia de varios centros con el mismo contacto.
-- ---------------------------------------------------------------------

CREATE TABLE members (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    name VARCHAR(100) NOT NULL,
    last_names VARCHAR(150) NOT NULL,
    cell_phone VARCHAR(10) NOT NULL,
    email VARCHAR(100),
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
    UNIQUE KEY uq_members_center_cell_phone (center_id, cell_phone),   -- [CAMBIO] era UNIQUE global
    UNIQUE KEY uq_members_center_email (center_id, email),             -- [NUEVO] era UNIQUE global inline
    CONSTRAINT fk_members_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_member_city FOREIGN KEY (city_id) REFERENCES cities(id),
    CONSTRAINT fk_members_colonia FOREIGN KEY (colonia_id)
        REFERENCES colonias(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_members_colonia_id (colonia_id),
    INDEX idx_members_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Catálogos y tarifas: + center_id (ADR-0001)
-- ---------------------------------------------------------------------

CREATE TABLE membership_config (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    days_number INT NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_grace_period INT,
    one_time_payment BOOLEAN NOT NULL DEFAULT FALSE,
    rate_id INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_membership_config_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_membership_config_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rates (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    days_number INT NOT NULL,
    concept VARCHAR(150) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    enabled BOOLEAN NOT NULL,
    username VARCHAR(100) NOT NULL,                       -- [CAMBIO] normalizado a 100
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    period_type VARCHAR(50) NOT NULL,
    is_favorite TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT fk_rates_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_rates_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE membership_config
    ADD CONSTRAINT fk_membership_config_rate
    FOREIGN KEY (rate_id) REFERENCES rates(id);

CREATE TABLE rates_table_history (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    value_changed VARCHAR(150) NOT NULL,
    rate_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_rates_history_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_rates_history_rate FOREIGN KEY (rate_id) REFERENCES rates(id),
    INDEX idx_rates_history_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rate_allowed_methods (
    rate_id INT NOT NULL,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    payment_method VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (rate_id, payment_method),
    CONSTRAINT fk_rate_allowed_methods_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_rate_allowed_methods_rate FOREIGN KEY (rate_id) REFERENCES rates(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Turnos y dinero: + center_id.
-- [PROVISIONAL] columnas de aprobación (ADR-0006 / ST-012): los valores
-- exactos se fijan al cerrar C-01 (¿bloquea o no la operación?).
-- ADR-0006 prefiere columnas en work_shifts sobre tabla separada.
-- ---------------------------------------------------------------------

CREATE TABLE work_shifts (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] caja por sucursal; máx. 1 turno abierto por sucursal (ADR-0010)
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    entry_amount DECIMAL(10,2) NOT NULL,
    responsible_user VARCHAR(100) NOT NULL,
    opening_reviewer_admin_user VARCHAR(100) NULL,       -- [CAMBIO] era NOT NULL; se llena cuando el CENTER_ADMIN aprueba la apertura, NULL mientras el turno está pendiente (ST-012)
    closing_reviewer_admin_user VARCHAR(100),
    -- [PROVISIONAL C-01] estado de aprobación por horario/desfase:
    approval_status VARCHAR(30) NOT NULL DEFAULT 'NONE', -- NONE|OPEN_PENDING_APPROVAL|CLOSED_PENDING_APPROVAL|APPROVED|REJECTED
    approval_requested_at TIMESTAMP NULL,
    approval_resolved_at TIMESTAMP NULL,
    approval_resolved_by VARCHAR(100),
    PRIMARY KEY (id),
    CONSTRAINT fk_work_shifts_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_work_shifts_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    INDEX idx_work_shifts_center_id (center_id),
    INDEX idx_work_shifts_branch_id (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE work_shifts_notes (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal del turno (ADR-0010)
    work_shift_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comments VARCHAR(150) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_work_shifts_notes_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_work_shifts_notes_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_work_shifts_notes_shift FOREIGN KEY (work_shift_id)
        REFERENCES work_shifts(id),
    INDEX idx_work_shifts_notes_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE debit_transactions (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal del turno donde nace el dinero (ADR-0010, inmutable)
    concept VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    work_shift_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comments VARCHAR(150),
    is_cancelled BOOLEAN DEFAULT 0,
    admin_user_cancellation_approval VARCHAR(100),
    PRIMARY KEY (id),
    CONSTRAINT fk_debit_transactions_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_debit_transactions_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_debit_transactions_shift FOREIGN KEY (work_shift_id)
        REFERENCES work_shifts(id),
    INDEX idx_debit_transactions_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cancellations (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal de la transacción cancelada
    debit_transaction_id INT NOT NULL UNIQUE,
    cancellation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    reason TEXT,
    cancelled_by_user VARCHAR(100) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_cancellations_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_cancellations_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_cancellations_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    INDEX idx_cancellations_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Suscripciones/membresías/cortesías: + center_id
-- ---------------------------------------------------------------------

CREATE TABLE member_membership (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    member_id INT NOT NULL,
    debit_transaction_id INT NOT NULL,
    membership_config_id INT NOT NULL,
    expiration_date TIMESTAMP NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT fk_member_membership_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_member_membership_member FOREIGN KEY (member_id) REFERENCES members(id),
    CONSTRAINT fk_member_membership_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    INDEX idx_member_membership_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subscriptions (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    member_id INT NOT NULL,
    debit_transaction_id INT NOT NULL,
    member_membership_id INT,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    period_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'EXPIRED',
    rate_id INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_subscriptions_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_subscriptions_member FOREIGN KEY (member_id) REFERENCES members(id),
    CONSTRAINT fk_subscriptions_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    INDEX idx_subscriptions_rate_id (rate_id),
    INDEX idx_subscriptions_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE subscription_history (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    subscription_id INT NOT NULL,
    description VARCHAR(250) NOT NULL,
    notes VARCHAR(250),
    username VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    action_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_subscription_history_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_subscription_history_subscription FOREIGN KEY (subscription_id)
        REFERENCES subscriptions(id) ON DELETE CASCADE,
    INDEX idx_subscription_history_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE courtesies (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
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
    CONSTRAINT fk_courtesies_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_courtesies_member FOREIGN KEY (member_id) REFERENCES members(id),
    INDEX idx_courtesies_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE courtesy_history (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    description VARCHAR(300) NOT NULL,
    courtesy_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action_type VARCHAR(20) NOT NULL,
    notes VARCHAR(250),
    PRIMARY KEY (id),
    CONSTRAINT fk_courtesy_history_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_courtesy_history_courtesy FOREIGN KEY (courtesy_id)
        REFERENCES courtesies(id) ON DELETE CASCADE,
    INDEX idx_courtesy_history_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Check-in: + center_id; se ELIMINA el UNIQUE global sobre
-- register_timestamp (dos centros harían colisión en el mismo segundo —
-- hallazgo de ADR-0001 / ST-004).
-- ---------------------------------------------------------------------

CREATE TABLE check_in (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal donde se registró la entrada (socio es del centro, ADR-0010)
    member_id INT NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    status VARCHAR(50),
    PRIMARY KEY (id),
    -- [CAMBIO] UNIQUE (register_timestamp) eliminado; índice normal en su lugar
    INDEX idx_check_in_register_timestamp (register_timestamp),
    CONSTRAINT fk_check_in_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_check_in_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_check_in_member FOREIGN KEY (member_id) REFERENCES members(id),
    INDEX idx_check_in_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE check_out (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] misma sucursal del check-in
    check_in_id INT NOT NULL,
    register_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_check_out_check_in_id (check_in_id),
    CONSTRAINT fk_check_out_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_check_out_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_check_out_check_in FOREIGN KEY (check_in_id) REFERENCES check_in(id),
    INDEX idx_check_out_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE checkin_subscription (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    checkin_id INT NOT NULL,
    subscription_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_checkin_subscription_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_checkin_subscription_checkin FOREIGN KEY (checkin_id) REFERENCES check_in(id),
    CONSTRAINT fk_checkin_subscription_subscription FOREIGN KEY (subscription_id)
        REFERENCES subscriptions(id),
    CONSTRAINT uq_checkin_subscription UNIQUE (checkin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE checkin_courtesy (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    checkin_id INT NOT NULL,
    courtesy_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_checkin_courtesy_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_checkin_courtesy_checkin FOREIGN KEY (checkin_id) REFERENCES check_in(id),
    CONSTRAINT fk_checkin_courtesy_courtesy FOREIGN KEY (courtesy_id) REFERENCES courtesies(id),
    CONSTRAINT uq_checkin_courtesy UNIQUE (checkin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE invalid_check_ins (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO] el intento se registra en el centro donde ocurrió
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal donde ocurrió el intento
    input_value VARCHAR(255),
    username VARCHAR(100),
    register_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_invalid_check_ins_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_invalid_check_ins_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    INDEX idx_invalid_check_ins_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Ventas, inventario y compras: + center_id y + branch_id
-- (ADR-0010). Catálogo de artículos a nivel CENTRO; stock por SUCURSAL.
-- ---------------------------------------------------------------------

CREATE TABLE articles (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO] catálogo del centro (precio único; override por sucursal = fase posterior)
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sale_price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL,                                  -- [CAMBIO] deja de ser fuente de verdad: el saldo real vive en branch_stock (ST-016)
    status TINYINT(1) NOT NULL DEFAULT 1,
    expiration_date TIMESTAMP NULL DEFAULT NULL,
    username VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_articles_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_articles_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- [NUEVO] Stock por sucursal (ADR-0010 regla 7). El saldo de cada
-- artículo existe por sucursal; las ventas descuentan de la sucursal
-- de la operación. Sustituye a articles.stock como fuente de verdad.
CREATE TABLE branch_stock (
    id INT NOT NULL AUTO_INCREMENT,
    branch_id INT UNSIGNED NOT NULL,
    article_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_branch_stock (branch_id, article_id),
    CONSTRAINT fk_branch_stock_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
    CONSTRAINT fk_branch_stock_article FOREIGN KEY (article_id) REFERENCES articles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE inventory (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] movimiento de inventario de esta sucursal
    type VARCHAR(50) NOT NULL,
    article_id INT NOT NULL,
    previous_quantity INT NOT NULL,
    current_quantity INT NOT NULL,
    description TEXT,
    register_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    username VARCHAR(100),
    CONSTRAINT fk_inventory_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_inventory_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_inventory_article FOREIGN KEY (article_id) REFERENCES articles(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_inventory_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sale (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal donde ocurrió la venta
    member_id INT NOT NULL,
    is_pending_payment BOOLEAN,
    is_cancelled BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    username VARCHAR(100),
    PRIMARY KEY (id),
    CONSTRAINT fk_sale_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_sale_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_sale_member FOREIGN KEY (member_id) REFERENCES members(id),
    INDEX idx_sale_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_articles (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    article_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_sale DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_cancelled BOOLEAN NOT NULL DEFAULT FALSE,
    sale_id INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_sales_articles_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_sales_articles_article FOREIGN KEY (article_id) REFERENCES articles(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sales_articles_sale FOREIGN KEY (sale_id) REFERENCES sale(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sales_details (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal de la venta/transacción
    debit_transaction_id INT NOT NULL,
    sale_id INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_sales_details_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_sales_details_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    CONSTRAINT fk_sales_details_transaction FOREIGN KEY (debit_transaction_id)
        REFERENCES debit_transactions(id),
    CONSTRAINT fk_sales_details_sale FOREIGN KEY (sale_id) REFERENCES sale(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    branch_id INT UNSIGNED NOT NULL,                     -- [NUEVO] sucursal que recibe la compra
    supplier TEXT,
    username VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_purchase_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_purchase_branch_center FOREIGN KEY (branch_id, center_id)
        REFERENCES branches(id, center_id),
    INDEX idx_purchase_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE purchase_details (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    article_id INT NOT NULL,
    purchase_id INT NOT NULL,
    quantity INT NOT NULL,
    purchase_price INT,
    PRIMARY KEY (id),
    CONSTRAINT fk_purchase_details_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_purchase_details_purchase FOREIGN KEY (purchase_id) REFERENCES purchase(id),
    CONSTRAINT fk_purchase_details_article FOREIGN KEY (article_id) REFERENCES articles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Perfil de sucursal y configuración de centro.
-- gym_profile pasa a branch_id (ADR-0010): cada sucursal física tiene su
-- propio nombre, teléfono, dirección y redes sociales — varían por ubicación.
-- gym_config se queda en center_id (ADR-0001/0008): dispositivos, métodos de
-- pago y páginas son compartidos por todo el centro.
-- P-10 (fusionar gym_profile con branches o mantenerla como extensión) sigue
-- abierta; aquí se muestra como extensión, opción preferida hoy.
-- ---------------------------------------------------------------------

CREATE TABLE gym_profile (
    id INT NOT NULL AUTO_INCREMENT,
    branch_id INT UNSIGNED NOT NULL,                     -- [CAMBIO] era center_id; pasa a sucursal física (ADR-0010): nombre, teléfono, dirección y redes varían por ubicación
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
    PRIMARY KEY (id),
    CONSTRAINT fk_gym_profile_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
    INDEX idx_gym_profile_branch_id (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gym_config (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    name VARCHAR(100) NOT NULL,
    type VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_gym_config_center FOREIGN KEY (center_id) REFERENCES centers(id),
    INDEX idx_gym_config_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE gym_config_history (
    id INT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    gym_config_id INT UNSIGNED NOT NULL,
    description VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_gym_config_history_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_gym_config FOREIGN KEY (gym_config_id) REFERENCES gym_config(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- [CAMBIO] Huellas y estatus de socio: + center_id (consulta directa en
-- check-in, ADR-0001/ST-004)
-- ---------------------------------------------------------------------

CREATE TABLE member_fingerprint_templates (
    id BIGINT NOT NULL AUTO_INCREMENT,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    member_id INT NOT NULL,
    template BLOB NOT NULL,
    created_by VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_member_fingerprint_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_member_fingerprint_member FOREIGN KEY (member_id) REFERENCES members(id),
    INDEX idx_member_fingerprint_center_id (center_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE member_status (
    member_id INT NOT NULL,
    center_id INT UNSIGNED NOT NULL,                     -- [NUEVO]
    status VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL,
    entity_id INT,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (member_id),
    CONSTRAINT fk_member_status_center FOREIGN KEY (center_id) REFERENCES centers(id),
    CONSTRAINT fk_member_status_member FOREIGN KEY (member_id)
        REFERENCES members(id) ON DELETE CASCADE,
    INDEX idx_member_status_status (status),
    INDEX idx_member_status_entity_id (entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Vista sin cambios estructurales: opera sobre member_id (único global),
-- sigue funcionando en multi-centro. [CAMBIO] expone center_id para que
-- los consumidores (reportes/queries) filtren por centro directamente
-- (ADR-0001 / ST-013).
-- ---------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_member_today_status AS
SELECT c.member_id,
       c.center_id,
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
       s.center_id,
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

-- =====================================================================
-- DATOS BASE — PLANTILLAS POR CENTRO Y SUCURSAL (ADR-0005/0010, ST-006/ST-015)
-- Los inserts de abajo son ilustrativos para UN centro (<cid>) y su
-- sucursal principal (<bid>). El alta de un centro (POST /centers) los
-- crea vía backend; los catálogos geográficos siguen globales.
-- =====================================================================

-- Global (sin centro):
INSERT INTO states (code, name) VALUES ('VER', 'Veracruz');

-- Sucursal principal del centro (una por centro al alta; más bajo /branches):
-- INSERT INTO branches (branch_uuid, center_id, name, active)
-- VALUES (UUID_TO_BIN(UUID(), 1), <cid>, 'Principal', TRUE);

-- Por centro (center_id = <cid>):
-- INSERT INTO gym_config (center_id, name, type, is_enabled) VALUES
--     (<cid>, 'Number Pad', 'DEVICE', 0),
--     (<cid>, 'Fingerprint', 'DEVICE', 0),
--     (<cid>, 'Hola!', 'GREETING', 1),
--     (<cid>, 'CASH', 'PAYMENT_METHOD', 1),
--     (<cid>, 'CARD', 'PAYMENT_METHOD', 1),
--     (<cid>, 'TRANSFER', 'PAYMENT_METHOD', 1),
--     (<cid>, 'dashboard', 'PAGE', 0),
--     (<cid>, 'calendar', 'PAGE', 0),
--     -- [PROVISIONAL ST-012] OPERATING_HOURS: gym_config (name/type/is_enabled)
--     -- no puede guardar horarios + desfase → ver pregunta M-05 en
--     -- preguntas-y-respuestas.md (añadir columna value/JSON o tabla de horario).
--     (<cid>, 'OPERATING_HOURS', 'SCHEDULE', 0);

-- INSERT INTO gym_profile (branch_id, name) VALUES (<bid>, '<nombre de la sucursal>');

-- Socios semilla internos (uno por centro):
-- INSERT INTO members (center_id, name, last_names, cell_phone, is_favorite, is_internal)
-- VALUES (<cid>, 'Público ', 'en General', '1111111111', FALSE, TRUE);
-- INSERT INTO members (center_id, name, last_names, cell_phone, is_favorite, is_internal)
-- VALUES (<cid>, 'Visita', 'público general', 'WALK_IN', FALSE, TRUE);

-- Usuario quiosco por sucursal (rol REGISTRATION, exento de formato correo, P-04):
-- INSERT INTO users (username, password, user_role, center_id, branch_id, created_by, enabled)
-- VALUES ('CHECKIN_<slug>', '<hash>', 'REGISTRATION', <cid>, <bid>, 'SYSTEM', TRUE);

-- El SUPERADMIN inicial NO se inserta aquí: lo crea DefaultAdminInitializer
-- al arrancar Spring Boot con credenciales por variables de entorno (P-03).
-- La instalación actual migra a: 1 centro + 1 sucursal "Principal" que
-- hereda todo el branch_id histórico (ST-014); su CHECKIN_GYM queda ligado
-- a esa sucursal.
