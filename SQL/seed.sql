USE inventory;

INSERT IGNORE INTO items (item_name, sku, quantity, warehouse_location) VALUES
  ('Wireless Barcode Scanner', 'NW-SCAN-001', 24, 'A-01-01'),
  ('Packing Tape Roll', 'NW-PACK-002', 180, 'A-01-02'),
  ('Shipping Label Pack', 'NW-LABEL-003', 75, 'A-02-01'),
  ('Safety Gloves', 'NW-SAFE-004', 64, 'B-01-01'),
  ('Steel Shelf Bracket', 'NW-SHELF-005', 42, 'B-01-02'),
  ('USB-C Dock', 'NW-DOCK-006', 18, 'B-02-01'),
  ('Thermal Printer', 'NW-PRINT-007', 9, 'C-01-01'),
  ('Pallet Wrap', 'NW-WRAP-008', 96, 'C-01-02'),
  ('Inventory Clipboard', 'NW-CLIP-009', 31, 'C-02-01'),
  ('Replacement Battery', 'NW-BATT-010', 27, 'C-02-02');
