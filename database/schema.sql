-- AutoCare PostgreSQL schema. Run once against an empty database.
CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(160) NOT NULL,
  email varchar(320) NOT NULL,
  phone varchar(50) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_customers_email UNIQUE (email)
);

CREATE TABLE public.service_centers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(160) NOT NULL,
  address varchar(300) NOT NULL,
  city varchar(100) NOT NULL,
  phone varchar(50) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_service_centers_name_city UNIQUE (name, city)
);

CREATE TABLE public.service_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(160) NOT NULL,
  description varchar(500) NOT NULL,
  estimated_duration_minutes integer NOT NULL,
  base_price numeric(10,2) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_service_types_name UNIQUE (name),
  CONSTRAINT ck_service_types_duration CHECK (estimated_duration_minutes > 0),
  CONSTRAINT ck_service_types_base_price CHECK (base_price >= 0)
);

CREATE TABLE public.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  make varchar(80) NOT NULL,
  model varchar(80) NOT NULL,
  model_year smallint NOT NULL,
  license_plate varchar(30) NOT NULL,
  mileage integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_vehicles_customer FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT uq_vehicles_license_plate UNIQUE (license_plate),
  CONSTRAINT uq_vehicles_id_customer UNIQUE (id, customer_id),
  CONSTRAINT ck_vehicles_year CHECK (model_year >= 1886),
  CONSTRAINT ck_vehicles_mileage CHECK (mileage >= 0)
);

CREATE TABLE public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL,
  vehicle_id uuid NOT NULL,
  service_center_id uuid NOT NULL,
  service_type_id uuid NOT NULL,
  scheduled_at timestamptz NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'scheduled',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT fk_bookings_vehicle_customer FOREIGN KEY (vehicle_id, customer_id) REFERENCES public.vehicles(id, customer_id),
  CONSTRAINT fk_bookings_service_center FOREIGN KEY (service_center_id) REFERENCES public.service_centers(id),
  CONSTRAINT fk_bookings_service_type FOREIGN KEY (service_type_id) REFERENCES public.service_types(id),
  CONSTRAINT ck_bookings_status CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled'))
);

CREATE INDEX ix_vehicles_customer_id ON public.vehicles (customer_id);
CREATE INDEX ix_bookings_service_center_scheduled_at ON public.bookings (service_center_id, scheduled_at);
CREATE INDEX ix_bookings_customer_scheduled_at ON public.bookings (customer_id, scheduled_at);
CREATE INDEX ix_bookings_vehicle_scheduled_at ON public.bookings (vehicle_id, scheduled_at);
