-- =============================================================================
-- Mock data for development environment
-- Passwords (bcrypt, cost 12):
--   admin users  → Admin@123
--   member users → Member@123
--   inactive     → Inactive@123
-- =============================================================================

-- -------------------------
-- Companies
-- -------------------------
INSERT INTO companies (id, name, created_at) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Acme Corp',        NOW() - INTERVAL '30 days'),
  ('00000000-0000-0000-0000-000000000002', 'Globex Industries', NOW() - INTERVAL '20 days'),
  ('00000000-0000-0000-0000-000000000003', 'Initech LLC',       NOW() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- -------------------------
-- Users
-- Company 1 — Acme Corp
-- -------------------------
INSERT INTO users (id, company_id, name, email, password_hash, role, is_active, created_at) VALUES
  (
    '00000000-0000-0001-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Admin Acme',
    'admin@acme.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oEiRr0Nqy',  -- Admin@123
    'admin',
    true,
    NOW() - INTERVAL '29 days'
  ),
  (
    '00000000-0000-0001-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Alice Silva',
    'alice@acme.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',  -- Member@123
    'member',
    true,
    NOW() - INTERVAL '25 days'
  ),
  (
    '00000000-0000-0001-0000-000000000003',
    '00000000-0000-0000-0000-000000000001',
    'Bob Santos',
    'bob@acme.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',  -- Member@123
    'member',
    true,
    NOW() - INTERVAL '20 days'
  ),
  (
    '00000000-0000-0001-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    'Inactive User',
    'inactive@acme.com',
    '$2b$12$eiooNBiAs/KBZnMuan5HiuUvBq9oJhwHkSg2ERlrxyfjwX0dKnf4S',  -- Inactive@123
    'member',
    false,
    NOW() - INTERVAL '15 days'
  )
ON CONFLICT (id) DO NOTHING;

-- -------------------------
-- Company 2 — Globex Industries
-- -------------------------
INSERT INTO users (id, company_id, name, email, password_hash, role, is_active, created_at) VALUES
  (
    '00000000-0000-0002-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    'Admin Globex',
    'admin@globex.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oEiRr0Nqy',  -- Admin@123
    'admin',
    true,
    NOW() - INTERVAL '19 days'
  ),
  (
    '00000000-0000-0002-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    'Carol Oliveira',
    'carol@globex.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',  -- Member@123
    'member',
    true,
    NOW() - INTERVAL '18 days'
  ),
  (
    '00000000-0000-0002-0000-000000000003',
    '00000000-0000-0000-0000-000000000002',
    'Inactive Globex',
    'inactive@globex.com',
    '$2b$12$eiooNBiAs/KBZnMuan5HiuUvBq9oJhwHkSg2ERlrxyfjwX0dKnf4S',  -- Inactive@123
    'member',
    false,
    NOW() - INTERVAL '10 days'
  )
ON CONFLICT (id) DO NOTHING;

-- -------------------------
-- Company 3 — Initech LLC
-- -------------------------
INSERT INTO users (id, company_id, name, email, password_hash, role, is_active, created_at) VALUES
  (
    '00000000-0000-0003-0000-000000000001',
    '00000000-0000-0000-0000-000000000003',
    'Admin Initech',
    'admin@initech.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4oEiRr0Nqy',  -- Admin@123
    'admin',
    true,
    NOW() - INTERVAL '9 days'
  ),
  (
    '00000000-0000-0003-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    'Dave Lima',
    'dave@initech.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',  -- Member@123
    'member',
    true,
    NOW() - INTERVAL '7 days'
  )
ON CONFLICT (id) DO NOTHING;

-- -------------------------
-- Audit Events
-- -------------------------
INSERT INTO audit_events (id, company_id, user_id, event_type, details, created_at) VALUES
  (
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0001-0000-000000000001',
    'user.login',
    '{"ip": "192.168.1.10"}',
    NOW() - INTERVAL '5 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0001-0000-000000000001',
    'user.created',
    '{"created_email": "alice@acme.com"}',
    NOW() - INTERVAL '25 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0002-0000-000000000001',
    'user.login',
    '{"ip": "10.0.0.5"}',
    NOW() - INTERVAL '3 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000001',
    NULL,
    'user.login_failed',
    '{"email": "unknown@acme.com", "ip": "203.0.113.42"}',
    NOW() - INTERVAL '1 day'
  )
ON CONFLICT (id) DO NOTHING;
