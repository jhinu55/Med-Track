DELIMITER //

CREATE PROCEDURE PROCESS_SALE(
    IN p_pharmacy_id INT,
    IN p_batch_id INT,
    IN p_qty INT,
    IN p_duration INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    -- Variable to hold current stock
    DECLARE v_stock INT;
    
    -- If any error happens, completely UNDO (Rollback) everything
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Start ACID Transaction
    START TRANSACTION;
    
    -- STEP 1: Check stock and LOCK the row so no one else can touch it
    SELECT quantity_on_hand INTO v_stock 
    FROM INVENTORY 
    WHERE pharmacy_id = p_pharmacy_id AND batch_id = p_batch_id 
    FOR UPDATE; -- This is the magic "Lock" command
    
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
        -- If stock is too low, cancel and throw an error
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for this batch.';
        ROLLBACK;
    END IF;
END //

DELIMITER ;