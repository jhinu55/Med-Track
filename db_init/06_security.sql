-- ============================================================
-- 06_security.sql
-- MedTrack Database Security Hardening
-- Purpose:
--   1) Create secure, role-oriented views (data masking + isolation)
--   2) Create RBAC roles
--   3) Apply least-privilege grants to roles
-- Notes:
--   - Designed for MySQL 8.x (roles supported).
--   - Idempotent where possible using IF EXISTS / IF NOT EXISTS.
--   - Run after core schema/procedures/triggers scripts.
-- ============================================================

USE PharmaGuard;

-- ============================================================
-- TASK 1: SECURE VIEWS (Data Masking & Isolation)
-- ============================================================

-- Drop and recreate to keep the script rerunnable.
DROP VIEW IF EXISTS vw_manufacturer_production;
DROP VIEW IF EXISTS vw_pharmacy_public_inventory;
DROP VIEW IF EXISTS vw_global_threat_dashboard;

-- 1) Manufacturer production view:
--    Shows batch + medicine production metadata without exposing current_owner_id.
--    This protects downstream ownership privacy while still enabling production tracking.
CREATE
    SQL SECURITY DEFINER
VIEW vw_manufacturer_production AS
SELECT
    b.batch_id,
    b.qr_code_hash,
    b.mfg_date,
    b.expiry_date,
    m.medicine_id,
    m.generic_name,
    m.brand_name,
    m.base_price
FROM BATCH b
INNER JOIN MEDICINE m
    ON m.medicine_id = b.medicine_id;

-- 2) Pharmacy public inventory view:
--    Hides exact quantity_on_hand and exposes only stock_status.
--    Prevents competitor scraping of precise stock numbers.
CREATE
    SQL SECURITY DEFINER
VIEW vw_pharmacy_public_inventory AS
SELECT
    i.pharmacy_id,
    i.batch_id,
    CASE
        WHEN i.quantity_on_hand > 0 THEN 'In Stock'
        ELSE 'Out of Stock'
    END AS stock_status,
    i.last_updated
FROM INVENTORY i;

-- 3) Global threat dashboard view:
--    Joins ALERT + BATCH + latest SCAN_LOG event per batch.
--    GPS is masked to city-level precision (2 decimals).
CREATE
    SQL SECURITY DEFINER
VIEW vw_global_threat_dashboard AS
SELECT
    a.alert_id,
    a.batch_id,
    a.alert_type,
    a.severity,
    a.alert_timestamp,
    b.medicine_id,
    b.expiry_date,
    ls.scan_timestamp AS latest_scan_timestamp,
    ROUND(ls.gps_lat, 2) AS masked_gps_lat,
    ROUND(ls.gps_long, 2) AS masked_gps_long
FROM ALERT a
INNER JOIN BATCH b
    ON b.batch_id = a.batch_id
LEFT JOIN (
    SELECT
        s1.batch_id,
        s1.scan_timestamp,
        s1.gps_lat,
        s1.gps_long
    FROM SCAN_LOG s1
    INNER JOIN (
        SELECT batch_id, MAX(scan_timestamp) AS max_scan_ts
        FROM SCAN_LOG
        GROUP BY batch_id
    ) s2
        ON s1.batch_id = s2.batch_id
       AND s1.scan_timestamp = s2.max_scan_ts
) ls
    ON ls.batch_id = a.batch_id;

-- ============================================================
-- TASK 2: CREATE MYSQL ROLES
-- ============================================================

CREATE ROLE IF NOT EXISTS `role_medtrack_admin`;
CREATE ROLE IF NOT EXISTS `role_medtrack_manufacturer`;
CREATE ROLE IF NOT EXISTS `role_medtrack_pharmacy`;

-- Reset role privilege surface before re-granting (safe for reruns).
REVOKE ALL PRIVILEGES, GRANT OPTION FROM `role_medtrack_admin`;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM `role_medtrack_manufacturer`;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM `role_medtrack_pharmacy`;

-- ============================================================
-- TASK 3: LEAST-PRIVILEGE GRANTS
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Admin Role
-- ------------------------------------------------------------
-- SELECT on all current/future tables and views in PharmaGuard.
GRANT SELECT ON PharmaGuard.* TO `role_medtrack_admin`;

-- Admin can resolve/update alerts.
GRANT UPDATE ON PharmaGuard.ALERT TO `role_medtrack_admin`;

-- Admin can execute TraceSupplyChain if present.
SET @trace_proc_exists := (
    SELECT COUNT(*)
    FROM information_schema.routines
    WHERE routine_schema = 'PharmaGuard'
      AND routine_type = 'PROCEDURE'
      AND routine_name = 'TraceSupplyChain'
);
SET @sql_trace_admin := IF(
    @trace_proc_exists > 0,
    'GRANT EXECUTE ON PROCEDURE PharmaGuard.TraceSupplyChain TO `role_medtrack_admin`',
    'SELECT ''Skip: procedure PharmaGuard.TraceSupplyChain not found'' AS info'
);
PREPARE stmt_trace_admin FROM @sql_trace_admin;
EXECUTE stmt_trace_admin;
DEALLOCATE PREPARE stmt_trace_admin;

-- ------------------------------------------------------------
-- 3.2 Manufacturer Role
-- ------------------------------------------------------------
-- Can create production and transfer records.
GRANT INSERT ON PharmaGuard.BATCH TO `role_medtrack_manufacturer`;
GRANT INSERT ON PharmaGuard.TRANSFER_LOG TO `role_medtrack_manufacturer`;

-- Can read medicine catalog and secure production view.
GRANT SELECT ON PharmaGuard.MEDICINE TO `role_medtrack_manufacturer`;
GRANT SELECT ON PharmaGuard.vw_manufacturer_production TO `role_medtrack_manufacturer`;

-- No grants to INVENTORY / SALE_TRANSACTION / ALERT are intentionally given.

-- ------------------------------------------------------------
-- 3.3 Pharmacy Role
-- ------------------------------------------------------------
-- Can read reference catalog and controlled stock visibility.
GRANT SELECT ON PharmaGuard.MEDICINE TO `role_medtrack_pharmacy`;
GRANT SELECT ON PharmaGuard.BATCH TO `role_medtrack_pharmacy`;
GRANT SELECT ON PharmaGuard.vw_pharmacy_public_inventory TO `role_medtrack_pharmacy`;

-- Operational writes.
GRANT INSERT ON PharmaGuard.TRANSFER_LOG TO `role_medtrack_pharmacy`;
GRANT INSERT ON PharmaGuard.SCAN_LOG TO `role_medtrack_pharmacy`;
GRANT INSERT ON PharmaGuard.SALE_TRANSACTION TO `role_medtrack_pharmacy`;
GRANT UPDATE ON PharmaGuard.INVENTORY TO `role_medtrack_pharmacy`;

-- Pharmacy can execute PROCESS_SALE if present.
SET @process_sale_exists := (
    SELECT COUNT(*)
    FROM information_schema.routines
    WHERE routine_schema = 'PharmaGuard'
      AND routine_type = 'PROCEDURE'
      AND routine_name = 'PROCESS_SALE'
);
SET @sql_process_sale := IF(
    @process_sale_exists > 0,
    'GRANT EXECUTE ON PROCEDURE PharmaGuard.PROCESS_SALE TO `role_medtrack_pharmacy`',
    'SELECT ''Skip: procedure PharmaGuard.PROCESS_SALE not found'' AS info'
);
PREPARE stmt_process_sale FROM @sql_process_sale;
EXECUTE stmt_process_sale;
DEALLOCATE PREPARE stmt_process_sale;

-- ============================================================
-- OPTIONAL HARDENING NOTES (uncomment after user migration)
-- ============================================================
-- 1) Create dedicated DB users and bind one role each:
--    CREATE USER IF NOT EXISTS 'api_admin'@'%' IDENTIFIED BY 'STRONG_PASSWORD';
--    CREATE USER IF NOT EXISTS 'api_manufacturer'@'%' IDENTIFIED BY 'STRONG_PASSWORD';
--    CREATE USER IF NOT EXISTS 'api_pharmacy'@'%' IDENTIFIED BY 'STRONG_PASSWORD';
--    GRANT `role_medtrack_admin` TO 'api_admin'@'%';
--    GRANT `role_medtrack_manufacturer` TO 'api_manufacturer'@'%';
--    GRANT `role_medtrack_pharmacy` TO 'api_pharmacy'@'%';
--    SET DEFAULT ROLE `role_medtrack_admin` TO 'api_admin'@'%';
--    SET DEFAULT ROLE `role_medtrack_manufacturer` TO 'api_manufacturer'@'%';
--    SET DEFAULT ROLE `role_medtrack_pharmacy` TO 'api_pharmacy'@'%';
--
-- 2) Remove legacy over-privileged grants only after application migration:
--    REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'medtrack'@'%';

