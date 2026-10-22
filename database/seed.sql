-- Idempotent development seed for AutoCare. Run after schema.sql.
INSERT INTO public.customers (id, name, email, phone) VALUES
  ('7B20C675-9B08-4D97-8A96-4FC79EAB8A01', 'Ananya Sharma', 'ananya.sharma@example.test', '+91-98765-43210')
ON CONFLICT DO NOTHING;

INSERT INTO public.vehicles (id, customer_id, make, model, model_year, license_plate, mileage) VALUES
  ('3F26AF51-9B4B-4A2A-B1D1-4FC79EAB8A02', '7B20C675-9B08-4D97-8A96-4FC79EAB8A01', 'Honda', 'City', 2022, 'KA01AB1234', 18500)
ON CONFLICT DO NOTHING;

INSERT INTO public.service_centers (id, name, address, city, phone) VALUES
  ('4C22F062-2D30-411D-9EB2-4FC79EAB8A03', 'AutoCare Indiranagar', '100 CMH Road', 'Bengaluru', '+91-80600-10000')
ON CONFLICT DO NOTHING;

INSERT INTO public.service_types (id, name, description, estimated_duration_minutes, base_price) VALUES
  ('B7F5C11A-4133-463B-A7D5-4FC79EAB8A04', 'Periodic service', 'Engine oil, filters, and multi-point inspection.', 90, 3499.00)
ON CONFLICT DO NOTHING;

INSERT INTO public.bookings (id, customer_id, vehicle_id, service_center_id, service_type_id, scheduled_at, status, notes) VALUES
  ('D3F85D4E-3D98-47E2-8B06-4FC79EAB8A05', '7B20C675-9B08-4D97-8A96-4FC79EAB8A01', '3F26AF51-9B4B-4A2A-B1D1-4FC79EAB8A02', '4C22F062-2D30-411D-9EB2-4FC79EAB8A03', 'B7F5C11A-4133-463B-A7D5-4FC79EAB8A04', '2026-10-15T09:30:00Z', 'confirmed', 'Please inspect the front brakes.')
ON CONFLICT DO NOTHING;
