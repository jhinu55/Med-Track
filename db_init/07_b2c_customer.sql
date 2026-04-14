-- ============================================================
-- 07_b2c_customer.sql
-- PharmaGuard B2C Extension:
--   1) CUSTOMER subclass table
--   2) Secure customer view
--   3) Customer RBAC role + least-privilege grants
-- Notes:
--   - Designed for MySQL 8.x.
--   - Safe to rerun using IF EXISTS / IF NOT EXISTS where possible.
--   - Run after 01_tables.sql and 06_security.sql.
-- ============================================================

USE PharmaGuard;

-- ============================================================
-- TASK 1: CUSTOMER subclass table (inherits from ACTOR)
-- ============================================================

-- Extend ACTOR role enum to include 'Customer'.
-- This keeps application-level role semantics aligned with the schema.
ALTER TABLE ACTOR
    MODIFY COLUMN role_type ENUM('Manufacturer', 'Pharmacy', 'Admin', 'Customer') NOT NULL;

-- CUSTOMER is a subtype of ACTOR:
-- - actor_id is both PK and FK to ACTOR(actor_id)
-- - ON DELETE CASCADE ensures orphan subtype records cannot survive
CREATE TABLE IF NOT EXISTS CUSTOMER (
    actor_id INT PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NULL,
    device_id VARCHAR(128) NULL,
    CONSTRAINT fk_customer_actor
        FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- ============================================================
-- TASK 2: Secure customer journey view
-- ============================================================

DROP VIEW IF EXISTS vw_customer_journey;

-- Customer-facing timeline:
-- - Joins BATCH + MEDICINE + TRANSFER_LOG
-- - Exposes only journey-safe fields
-- - Ordered chronologically for timeline rendering
CREATE
    SQL SECURITY DEFINER
VIEW vw_customer_journey AS
SELECT
    b.qr_code_hash,
    m.brand_name,
    m.generic_name,
    b.expiry_date,
    t.transfer_date,
    t.status
FROM BATCH b
INNER JOIN MEDICINE m
    ON m.medicine_id = b.medicine_id
INNER JOIN TRANSFER_LOG t
    ON t.batch_id = b.batch_id
ORDER BY t.transfer_date ASC;

-- ============================================================
-- TASK 3: RBAC for customer role
-- ============================================================

CREATE ROLE IF NOT EXISTS `role_medtrack_customer`;

-- Reset role privilege surface before re-granting.
REVOKE ALL PRIVILEGES, GRANT OPTION FROM `role_medtrack_customer`;

-- Customer can read only curated journey data (no raw BATCH/TRANSFER_LOG access).
GRANT SELECT ON PharmaGuard.vw_customer_journey TO `role_medtrack_customer`;

-- Customer app can record scans for anomaly/velocity checks.
GRANT INSERT ON PharmaGuard.SCAN_LOG TO `role_medtrack_customer`;

-- Customer can read general medicine catalog details.
GRANT SELECT ON PharmaGuard.MEDICINE TO `role_medtrack_customer`;

-- Optional assignment examples (uncomment after user creation):
-- GRANT `role_medtrack_customer` TO 'api_customer'@'%';
-- SET DEFAULT ROLE `role_medtrack_customer` TO 'api_customer'@'%';
