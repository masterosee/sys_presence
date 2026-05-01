-- ============================================================
-- CONATEL - Système de Présence
-- Schéma PostgreSQL
-- ============================================================

-- Extension pour UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis"; -- pour GPS (optionnel, fallback ci-dessous)

-- ============================================================
-- 1. DÉPARTEMENTS
-- ============================================================
CREATE TABLE departments (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(20) UNIQUE NOT NULL,
    description TEXT,
    manager_id  UUID,  -- référence vers employees (ajoutée après)
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. POSTES / FONCTIONS
-- ============================================================
CREATE TABLE positions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title         VARCHAR(100) NOT NULL,
    department_id UUID REFERENCES departments(id),
    level         VARCHAR(50),  -- junior, senior, chef, directeur...
    is_active     BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. EMPLOYÉS
-- ============================================================
CREATE TABLE employees (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code   VARCHAR(20) UNIQUE NOT NULL,  -- ex: CNT-001
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone           VARCHAR(20),
    department_id   UUID REFERENCES departments(id),
    position_id     UUID REFERENCES positions(id),
    hire_date       DATE NOT NULL,
    contract_type   VARCHAR(30) DEFAULT 'CDI',  -- CDI, CDD, Stage, Consultant
    photo_url       TEXT,
    pin_code        VARCHAR(6),                  -- PIN hashé bcrypt
    is_remote       BOOLEAN DEFAULT FALSE,       -- travaille à distance ?
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Ajouter manager_id après création de employees
ALTER TABLE departments
    ADD CONSTRAINT fk_dept_manager
    FOREIGN KEY (manager_id) REFERENCES employees(id);

-- ============================================================
-- 4. COMPTES UTILISATEURS (accès app)
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id     UUID UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    username        VARCHAR(50) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,       -- bcrypt
    role            VARCHAR(20) DEFAULT 'employee', -- employee, rh, manager, admin
    last_login      TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. HORAIRES DE TRAVAIL
-- ============================================================
CREATE TABLE work_schedules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,       -- ex: "8h-17h Lundi-Vendredi"
    start_time      TIME NOT NULL,               -- 08:00
    end_time        TIME NOT NULL,               -- 17:00
    break_duration  INTEGER DEFAULT 60,          -- minutes de pause déjeuner
    work_days       INTEGER[] DEFAULT '{1,2,3,4,5}', -- 1=Lundi ... 7=Dimanche
    grace_minutes   INTEGER DEFAULT 15,          -- tolérance retard en minutes
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Assignation d'horaire à un employé
CREATE TABLE employee_schedules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id     UUID REFERENCES employees(id) ON DELETE CASCADE,
    schedule_id     UUID REFERENCES work_schedules(id),
    start_date      DATE NOT NULL,
    end_date        DATE,                        -- NULL = en cours
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. ZONES AUTORISÉES (Geofences pour pointage distant)
-- ============================================================
CREATE TABLE geofences (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,       -- ex: "Bureau CONATEL Principal"
    description     TEXT,
    latitude        DECIMAL(10, 8) NOT NULL,
    longitude       DECIMAL(11, 8) NOT NULL,
    radius_meters   INTEGER DEFAULT 200,         -- rayon en mètres
    is_office       BOOLEAN DEFAULT TRUE,        -- bureau principal ou terrain
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Zones autorisées par département
CREATE TABLE department_geofences (
    department_id   UUID REFERENCES departments(id) ON DELETE CASCADE,
    geofence_id     UUID REFERENCES geofences(id) ON DELETE CASCADE,
    PRIMARY KEY (department_id, geofence_id)
);

-- ============================================================
-- 7. QR CODES DYNAMIQUES
-- ============================================================
CREATE TABLE qr_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token           VARCHAR(64) UNIQUE NOT NULL, -- token secret du QR
    geofence_id     UUID REFERENCES geofences(id),
    generated_at    TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,        -- +30 secondes
    is_used         BOOLEAN DEFAULT FALSE        -- sécurité supplémentaire
);

-- ============================================================
-- 8. POINTAGES (table principale)
-- ============================================================
CREATE TABLE attendances (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id     UUID REFERENCES employees(id) ON DELETE CASCADE,
    date            DATE NOT NULL,               -- jour du pointage
    check_in        TIMESTAMPTZ,                 -- heure d'arrivée
    check_out       TIMESTAMPTZ,                 -- heure de départ
    
    -- Méthode de pointage
    check_in_method  VARCHAR(20),               -- qr_code, pin, gps, nfc, biometric
    check_out_method VARCHAR(20),

    -- GPS
    check_in_lat     DECIMAL(10, 8),
    check_in_lng     DECIMAL(11, 8),
    check_out_lat    DECIMAL(10, 8),
    check_out_lng    DECIMAL(11, 8),
    geofence_id      UUID REFERENCES geofences(id),
    
    -- Photos (pointage à distance)
    check_in_photo   TEXT,                       -- URL photo selfie entrée
    check_out_photo  TEXT,                       -- URL photo selfie sortie

    -- Statut
    status          VARCHAR(20) DEFAULT 'present', 
                    -- present, late, absent, half_day, remote, on_leave
    is_late         BOOLEAN DEFAULT FALSE,
    late_minutes    INTEGER DEFAULT 0,
    
    -- Durée
    work_duration   INTEGER,                     -- minutes travaillées
    
    -- Notes
    notes           TEXT,
    approved_by     UUID REFERENCES employees(id),
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    
    -- Un seul pointage par employé par jour
    UNIQUE (employee_id, date)
);

-- ============================================================
-- 9. CONGÉS ET ABSENCES
-- ============================================================
CREATE TABLE leave_types (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(50) NOT NULL,   -- Congé annuel, Maladie, Maternité...
    code        VARCHAR(20) UNIQUE NOT NULL,
    max_days    INTEGER,                -- jours maximum par an
    is_paid     BOOLEAN DEFAULT TRUE,
    color       VARCHAR(7) DEFAULT '#6366F1' -- couleur hex pour le calendrier
);

CREATE TABLE leave_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id     UUID REFERENCES employees(id) ON DELETE CASCADE,
    leave_type_id   UUID REFERENCES leave_types(id),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    total_days      INTEGER NOT NULL,
    reason          TEXT,
    status          VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    reviewed_by     UUID REFERENCES employees(id),
    reviewed_at     TIMESTAMPTZ,
    review_comment  TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. AUDIT LOG (traçabilité complète)
-- ============================================================
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID REFERENCES users(id),
    action      VARCHAR(50) NOT NULL,       -- LOGIN, CHECKIN, CHECKOUT, UPDATE...
    entity      VARCHAR(50),               -- attendance, employee, leave...
    entity_id   UUID,
    details     JSONB,                     -- données supplémentaires
    ip_address  INET,
    device_info TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEX (performance)
-- ============================================================
CREATE INDEX idx_attendances_employee_date ON attendances(employee_id, date);
CREATE INDEX idx_attendances_date ON attendances(date);
CREATE INDEX idx_attendances_status ON attendances(status);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX idx_qr_sessions_token ON qr_sessions(token);
CREATE INDEX idx_qr_sessions_expires ON qr_sessions(expires_at);
CREATE INDEX idx_employees_department ON employees(department_id);

-- ============================================================
-- TRIGGERS : updated_at automatique
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employees_updated
    BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_users_updated
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_attendances_updated
    BEFORE UPDATE ON attendances
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_leave_requests_updated
    BEFORE UPDATE ON leave_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- DONNÉES INITIALES
-- ============================================================
INSERT INTO work_schedules (name, start_time, end_time, break_duration, grace_minutes)
VALUES ('Standard CONATEL', '08:00', '17:00', 60, 15);

INSERT INTO leave_types (name, code, max_days, is_paid, color) VALUES
('Congé annuel',    'ANNUAL',    30, TRUE,  '#6366F1'),
('Congé maladie',   'SICK',      15, TRUE,  '#F59E0B'),
('Congé maternité', 'MATERNITY', 90, TRUE,  '#EC4899'),
('Congé paternité', 'PATERNITY',  5, TRUE,  '#3B82F6'),
('Sans solde',      'UNPAID',    30, FALSE, '#6B7280');

-- Admin par défaut
INSERT INTO departments (name, code) VALUES ('Administration', 'ADMIN');

COMMENT ON TABLE attendances IS 'Table principale des pointages employés';
COMMENT ON TABLE qr_sessions IS 'QR codes dynamiques - expire toutes les 30 secondes';
COMMENT ON TABLE geofences IS 'Zones GPS autorisées pour le pointage à distance';
