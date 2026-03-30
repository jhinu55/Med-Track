DELIMITER //

-- Drop the old one if it exists so we can replace it
DROP PROCEDURE IF EXISTS PROCESS_SALE //

CREATE PROCEDURE PROCESS_SALE(
    IN p_pharmacy_id INT,
    IN p_batch_id INT,
    IN p_qty INT,
    IN p_duration INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_risk_score INT DEFAULT 0;
    DECLARE v_distinct_pharmacies INT DEFAULT 0;
    
    -- If any error happens, completely UNDO (Rollback) everything
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Start ACID Transaction
    START TRANSACTION;
    
    -- ====================================================
    -- PHASE A: REAL-TIME COUNTERFEIT RISK CALCULATION
    -- ====================================================
    
    -- RULE 1: Velocity / Cloning Check
    -- Look at the SCAN_LOG. Has this exact batch been scanned by DIFFERENT pharmacies in the last 24 hours?
    -- A physical box cannot exist in two different stores on the same day.
    SELECT COUNT(DISTINCT scanned_by) INTO v_distinct_pharmacies 
    FROM SCAN_LOG 
    WHERE batch_id = p_batch_id 
      AND scan_timestamp >= NOW() - INTERVAL 24 HOUR;
      
    -- If more than 1 pharmacy scanned this today, spike the risk score.
    IF v_distinct_pharmacies > 1 THEN
        SET v_risk_score = v_risk_score + 80; 
    END IF;

    -- RULE 2: The Action Trigger
    -- If the Risk Score crosses the threshold, BLOCK the sale immediately.
    IF v_risk_score >= 50 THEN
        -- 1. Secretly log a high-severity alert for the Admin
        INSERT INTO ALERT (batch_id, alert_type, severity) 
        VALUES (p_batch_id, 'Counterfeit-Flag', 'High');
        
        -- 2. Hard block the transaction, sending a 403 error back to the Flask API
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Transaction Blocked: High Counterfeit Risk Score (Duplicate geographic scans detected).';
    END IF;

    -- ====================================================
    -- PHASE B: INVENTORY DEDUCTION (ACID Locks)
    -- ====================================================
    
    -- STEP 1: Check stock and LOCK the row
    SELECT quantity_on_hand INTO v_stock 
    FROM INVENTORY 
    WHERE pharmacy_id = p_pharmacy_id AND batch_id = p_batch_id 
    FOR UPDATE; 
    
    IF v_stock >= p_qty THEN
        -- STEP 2: Deduct Stock
        UPDATE INVENTORY 
        SET quantity_on_hand = quantity_on_hand - p_qty 
        WHERE pharmacy_id = p_pharmacy_id AND batch_id = p_batch_id;
        
        -- STEP 3: Record the Sale
        INSERT INTO SALE_TRANSACTION (pharmacy_id, batch_id, quantity_sold, treatment_duration_days, override_reason)
        VALUES (p_pharmacy_id, p_batch_id, p_qty, p_duration, p_reason);
        
        -- If all steps succeed, save permanently
        COMMIT;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for this batch.';
    END IF;
END //

DELIMITER ;