-- ============================================================
-- La Alameda — Supabase Schema v2
-- Ejecutar en: Supabase Dashboard > SQL Editor > New query
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── PROFILES ─────────────────────────────────────────────────
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  tower       TEXT NOT NULL,          -- '1','2','3','4A','4B','8','9','Casa'
  apartment   TEXT NOT NULL,          -- número de apto o de casa
  unit_type   TEXT NOT NULL DEFAULT 'apartamento'
                CHECK (unit_type IN ('apartamento', 'casa')),
  role        TEXT NOT NULL DEFAULT 'resident'
                CHECK (role IN ('resident', 'admin')),
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
  fcm_token   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── AMENITIES ────────────────────────────────────────────────
CREATE TABLE amenities (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug          TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT,
  image_url     TEXT,
  open_hour     SMALLINT NOT NULL DEFAULT 7,
  close_hour    SMALLINT NOT NULL DEFAULT 21,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO amenities (slug, name, description, open_hour, close_hour)
VALUES ('tenis', 'Cancha de tenis', 'Cancha de tenis profesional', 7, 21);

-- ── RESERVATIONS ─────────────────────────────────────────────
-- La cuota (3/semana, 1/día) es POR UNIDAD (torre+apartamento),
-- no por usuario, para que varios residentes del mismo apto compartan el límite.
CREATE TABLE reservations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Denormalizamos tower+apartment para hacer los checks sin JOIN
  tower             TEXT NOT NULL,
  apartment         TEXT NOT NULL,
  amenity_id        TEXT NOT NULL REFERENCES amenities(slug),
  reservation_date  DATE NOT NULL,
  start_hour        SMALLINT NOT NULL CHECK (start_hour BETWEEN 7 AND 20),
  end_hour          SMALLINT NOT NULL CHECK (end_hour BETWEEN 8 AND 21),
  status            TEXT NOT NULL DEFAULT 'confirmed'
                      CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),

  -- Un slot por cancha por hora (ignorando canceladas)
  CONSTRAINT unique_slot UNIQUE (amenity_id, reservation_date, start_hour, status)
    DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_reservations_user_date  ON reservations (user_id, reservation_date);
CREATE INDEX idx_reservations_unit       ON reservations (tower, apartment, reservation_date);
CREATE INDEX idx_reservations_slot       ON reservations (amenity_id, reservation_date, status);

-- ── REGLAS DE NEGOCIO ─────────────────────────────────────────
-- 1 reserva por día por UNIDAD (torre+apto)
CREATE OR REPLACE FUNCTION check_daily_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (
    SELECT COUNT(*) FROM reservations
    WHERE tower = NEW.tower
      AND apartment = NEW.apartment
      AND amenity_id = NEW.amenity_id
      AND reservation_date = NEW.reservation_date
      AND status = 'confirmed'
      AND id IS DISTINCT FROM NEW.id
  ) >= 1 THEN
    RAISE EXCEPTION 'Ya hay una reserva para esta unidad este día.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_daily_limit
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW EXECUTE FUNCTION check_daily_limit();

-- 3 reservas por semana por UNIDAD (torre+apto)
CREATE OR REPLACE FUNCTION check_weekly_limit()
RETURNS TRIGGER AS $$
BEGIN
  IF (
    SELECT COUNT(*) FROM reservations
    WHERE tower = NEW.tower
      AND apartment = NEW.apartment
      AND amenity_id = NEW.amenity_id
      AND status = 'confirmed'
      AND reservation_date >= DATE_TRUNC('week', NEW.reservation_date)
      AND reservation_date <  DATE_TRUNC('week', NEW.reservation_date) + INTERVAL '7 days'
      AND id IS DISTINCT FROM NEW.id
  ) >= 3 THEN
    RAISE EXCEPTION 'Esta unidad alcanzó el máximo de 3 reservas por semana.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_weekly_limit
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW EXECUTE FUNCTION check_weekly_limit();

-- ── ROW LEVEL SECURITY ────────────────────────────────────────
ALTER TABLE profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE amenities    ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);

-- amenities: visible para todos los autenticados
CREATE POLICY "amenities_select_all" ON amenities FOR SELECT TO authenticated USING (true);

-- reservations: cada residente ve todas las de su unidad (para saber el cupo compartido)
CREATE POLICY "reservations_select_unit" ON reservations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND p.tower = reservations.tower
        AND p.apartment = reservations.apartment
    )
  );
CREATE POLICY "reservations_insert_own" ON reservations FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reservations_update_own" ON reservations FOR UPDATE
  USING (auth.uid() = user_id);

-- ── AUTO-CREAR PROFILE AL REGISTRARSE ────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, tower, apartment, unit_type, role, status)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Residente'),
    COALESCE(NEW.raw_user_meta_data->>'tower', '1'),
    COALESCE(NEW.raw_user_meta_data->>'apartment', ''),
    COALESCE(NEW.raw_user_meta_data->>'unit_type', 'apartamento'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'resident'),
    COALESCE(NEW.raw_user_meta_data->>'status', 'pending')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── updated_at automático ─────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_reservations_updated_at
  BEFORE UPDATE ON reservations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
