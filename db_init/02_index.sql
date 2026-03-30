-- 1. Implement the B-Tree Index for the Expiry Date sweeps
CREATE INDEX idx_batch_expiry ON BATCH(expiry_date);

-- 2. Implement the Index for the QR Code lookups
CREATE UNIQUE INDEX idx_qr_hash ON BATCH(qr_code_hash);