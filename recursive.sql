DELIMITER //

CREATE PROCEDURE TraceSupplyChain(
    IN p_batch_id INT,
    IN p_end_actor_id INT
)
BEGIN
    WITH RECURSIVE SupplyChainTrace AS (
        -- PART 1: THE ANCHOR
        SELECT 
            transfer_id, batch_id, sender_id, receiver_id, transfer_date, 
            1 AS traceback_step 
        FROM TRANSFER_LOG
        WHERE batch_id = p_batch_id AND receiver_id = p_end_actor_id 
        
        UNION ALL
        
        -- PART 2: THE RECURSION
        SELECT 
            t.transfer_id, t.batch_id, t.sender_id, t.receiver_id, t.transfer_date, 
            sct.traceback_step + 1
        FROM TRANSFER_LOG t
        INNER JOIN SupplyChainTrace sct 
            ON t.receiver_id = sct.sender_id 
            AND t.batch_id = sct.batch_id
    )
    
    -- PART 3: THE RESULT
    SELECT * FROM SupplyChainTrace 
    ORDER BY traceback_step ASC;
END //

DELIMITER ;