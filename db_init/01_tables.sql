-- Create the main database and use it
CREATE DATABASE IF NOT EXISTS PharmaGuard;
USE PharmaGuard;

-- ==========================================
-- 1. THE ACTOR HIERARCHY (Inheritance)
-- ==========================================

-- The Superclass
CREATE TABLE ACTOR (
    actor_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role_type ENUM('Manufacturer', 'Pharmacy', 'Admin') NOT NULL,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subclass 1: Manufacturer
CREATE TABLE MANUFACTURER (
    actor_id INT PRIMARY KEY,
    license_no VARCHAR(50) NOT NULL UNIQUE,
    production_capacity INT,
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- Subclass 2: Pharmacy
CREATE TABLE PHARMACY (
    actor_id INT PRIMARY KEY,
    pharmacy_license VARCHAR(50) NOT NULL UNIQUE,
    gps_lat DECIMAL(10, 8) NOT NULL,  -- Crucial for Velocity Checks
    gps_long DECIMAL(11, 8) NOT NULL,
    address  VARCHAR(255) DEFAULT NULL,
    city     VARCHAR(100) DEFAULT NULL,
    state    VARCHAR(100) DEFAULT NULL,
    pincode  VARCHAR(10)  DEFAULT NULL,
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- Subclass 3: Admin (Added to match your final ER Diagram)
CREATE TABLE ADMIN (
    actor_id INT PRIMARY KEY,
    security_clearance_level INT DEFAULT 1,
    FOREIGN KEY (actor_id) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- ==========================================
-- 2. THE CORE DATA ENTITIES
-- ==========================================

-- The Blueprint
CREATE TABLE MEDICINE (
    medicine_id INT AUTO_INCREMENT PRIMARY KEY,
    generic_name VARCHAR(100) NOT NULL,
    brand_name VARCHAR(100) NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL
);

-- The Physical Item (The Hub)
CREATE TABLE BATCH (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id INT NOT NULL,
    qr_code_hash VARCHAR(64) NOT NULL UNIQUE, -- SHA-256 hash for security
    mfg_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    current_owner_id INT NOT NULL, -- Tracks who legally holds it right now
    batch_status ENUM('Active', 'WARNING', 'BLOCKED') NOT NULL DEFAULT 'Active',
    
    FOREIGN KEY (medicine_id) REFERENCES MEDICINE(medicine_id) ON DELETE RESTRICT,
    FOREIGN KEY (current_owner_id) REFERENCES ACTOR(actor_id) ON DELETE RESTRICT
);

-- ==========================================
-- 3. THE ACTION ENTITIES (Phase 2)
-- ==========================================

-- 6. INVENTORY (The Associative Entity)
CREATE TABLE INVENTORY (
    pharmacy_id INT NOT NULL,
    batch_id INT NOT NULL,
    quantity_on_hand INT NOT NULL DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Composite Primary Key (A pharmacy can only have one inventory record per specific batch)
    PRIMARY KEY (pharmacy_id, batch_id),
    FOREIGN KEY (pharmacy_id) REFERENCES PHARMACY(actor_id) ON DELETE CASCADE,
    FOREIGN KEY (batch_id) REFERENCES BATCH(batch_id) ON DELETE CASCADE
);

-- 7. TRANSFER_LOG (The Chain of Custody)
CREATE TABLE TRANSFER_LOG (
    transfer_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    sender_id INT NOT NULL,   -- Who sent it?
    receiver_id INT NOT NULL, -- Who received it?
    transfer_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Initiated', 'In-Transit', 'Received', 'Rejected') DEFAULT 'Initiated',
    
    FOREIGN KEY (batch_id) REFERENCES BATCH(batch_id) ON DELETE RESTRICT,
    FOREIGN KEY (sender_id) REFERENCES ACTOR(actor_id) ON DELETE RESTRICT,
    FOREIGN KEY (receiver_id) REFERENCES ACTOR(actor_id) ON DELETE RESTRICT
);

-- 8. SALE_TRANSACTION (The Smart Expiry Audit)
CREATE TABLE SALE_TRANSACTION (
    txn_id INT AUTO_INCREMENT PRIMARY KEY,
    pharmacy_id INT NOT NULL,
    batch_id INT NOT NULL,
    quantity_sold INT NOT NULL,
    sale_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- "Smart Expiry" Audit Fields
    treatment_duration_days INT,         
    override_reason VARCHAR(255),        
    
    FOREIGN KEY (pharmacy_id) REFERENCES PHARMACY(actor_id) ON DELETE RESTRICT,
    FOREIGN KEY (batch_id) REFERENCES BATCH(batch_id) ON DELETE RESTRICT
);

-- ==========================================
-- 4. THE SECURITY ENTITIES (Phase 3)
-- ==========================================

-- 9. SCAN_LOG (The Velocity Tracker)
CREATE TABLE SCAN_LOG (
    scan_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    scanned_by INT NOT NULL, -- Who scanned it?
    gps_lat DECIMAL(10, 8) NOT NULL,
    gps_long DECIMAL(11, 8) NOT NULL,
    scan_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (batch_id) REFERENCES BATCH(batch_id) ON DELETE CASCADE,
    FOREIGN KEY (scanned_by) REFERENCES ACTOR(actor_id) ON DELETE CASCADE
);

-- 10. ALERT (The Admin Dashboard Feed)
CREATE TABLE ALERT (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    alert_type ENUM('Geo-Anomaly', 'Expired-Attempt', 'Counterfeit-Flag') NOT NULL,
    severity ENUM('Low', 'Medium', 'High') NOT NULL,
    alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (batch_id) REFERENCES BATCH(batch_id) ON DELETE CASCADE
);

