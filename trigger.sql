DELIMITER //

CREATE TRIGGER Prevent_Expired_Sale
BEFORE INSERT ON SALE_TRANSACTION
FOR EACH ROW
BEGIN
    DECLARE v_expiry DATE;
    
    -- Find out when this batch expires
    SELECT expiry_date INTO v_expiry 
    FROM BATCH 
    WHERE batch_id = NEW.batch_id;
    
    -- Rule: If it's expired AND the pharmacist didn't provide a justification
    IF v_expiry < CURDATE() AND NEW.override_reason IS NULL THEN
        
        -- 1. Secretly log an alert for the Admin
        INSERT INTO ALERT (batch_id, alert_type, severity) 
        VALUES (NEW.batch_id, 'Expired-Attempt', 'High');
        
        -- 2. Hard block the transaction
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Transaction Blocked: Medicine is expired. Admin override reason required.';
    END IF;
END //

DELIMITER ;