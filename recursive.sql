-- Replace '101' with the actual batch_id you want to investigate
-- Replace '5' with the actor_id of the Pharmacy where it was found

WITH RECURSIVE SupplyChainTrace AS (
    
    -- ==========================================
    -- PART 1: THE ANCHOR (The Starting Point)
    -- ==========================================
    -- We start at the end of the chain (the Pharmacy that flagged it)
    SELECT 
        transfer_id, 
        batch_id, 
        sender_id, 
        receiver_id, 
        transfer_date, 
        1 AS traceback_step -- We count how many steps back we go
    FROM TRANSFER_LOG
    WHERE batch_id = 101 AND receiver_id = 5 
    
    UNION ALL
    
    -- ==========================================
    -- PART 2: THE RECURSIVE LOOP (Climbing up the chain)
    -- ==========================================
    -- We take the 'sender' from the previous step and look for the 
    -- record where THEY were the 'receiver'.
    SELECT 
        t.transfer_id, 
        t.batch_id, 
        t.sender_id, 
        t.receiver_id, 
        t.transfer_date, 
        sct.traceback_step + 1
    FROM TRANSFER_LOG t
    INNER JOIN SupplyChainTrace sct 
        ON t.receiver_id = sct.sender_id -- Match previous sender to current receiver
        AND t.batch_id = sct.batch_id
)

-- ==========================================
-- PART 3: THE RESULT
-- ==========================================
SELECT * FROM SupplyChainTrace 
ORDER BY traceback_step ASC;