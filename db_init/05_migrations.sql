-- Migration: add address fields to PHARMACY and batch_status to BATCH
USE PharmaGuard;

-- Add address columns to PHARMACY (idempotent via ALTER IGNORE / column existence check)
ALTER TABLE PHARMACY
    ADD COLUMN IF NOT EXISTS address  VARCHAR(255) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS city     VARCHAR(100) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS state    VARCHAR(100) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS pincode  VARCHAR(10)  DEFAULT NULL;

-- Add batch_status column to BATCH
ALTER TABLE BATCH
    ADD COLUMN IF NOT EXISTS batch_status ENUM('Active', 'WARNING', 'BLOCKED') NOT NULL DEFAULT 'Active';
