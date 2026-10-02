
create table if not exists public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  full_name text not null default '',
  email text not null default '',
  job_title text not null default 'Receptionist',
  status text not null default 'pending',
  permissions text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.staff_profiles to authenticated;
grant all on public.staff_profiles to service_role;
alter table public.staff_profiles enable row level security;
create policy "Staff read own profile" on public.staff_profiles for select to authenticated using (auth.uid() = user_id);
create policy "Admins read staff profiles" on public.staff_profiles for select to authenticated using (public.has_role(auth.uid(), 'admin'));
create policy "Staff create own pending profile" on public.staff_profiles for insert to authenticated with check (auth.uid() = user_id and status = 'pending' and permissions = '{}');
create policy "Admins manage staff profiles" on public.staff_profiles for update to authenticated using (public.has_role(auth.uid(), 'admin')) with check (public.has_role(auth.uid(), 'admin'));
create policy "Admins delete staff profiles" on public.staff_profiles for delete to authenticated using (public.has_role(auth.uid(), 'admin'));
create trigger staff_profiles_set_updated_at before update on public.staff_profiles for each row execute function public.set_updated_at();

-- helper: is the user an approved staff member or admin
create or replace function public.staff_can(_user_id uuid, _perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles r where r.user_id = _user_id and r.role = 'admin')
      or exists (
        select 1 from public.staff_profiles s
        where s.user_id = _user_id and s.status = 'approved' and _perm = any(s.permissions)
      )
$$;

create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  email text not null default '',
  gender text not null default '',
  date_of_birth date,
  address text not null default '',
  medical_notes text not null default '',
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists patients_name_idx on public.patients (lower(full_name));
create index if not exists patients_phone_idx on public.patients (phone);
grant select, insert, update, delete on public.patients to authenticated;
grant all on public.patients to service_role;
alter table public.patients enable row level security;
create policy "Staff view patients" on public.patients for select to authenticated using (public.staff_can(auth.uid(), 'patients_view'));
create policy "Staff add patients" on public.patients for insert to authenticated with check (public.staff_can(auth.uid(), 'patients_edit'));
create policy "Staff update patients" on public.patients for update to authenticated using (public.staff_can(auth.uid(), 'patients_edit')) with check (public.staff_can(auth.uid(), 'patients_edit'));
create policy "Admins delete patients" on public.patients for delete to authenticated using (public.has_role(auth.uid(), 'admin'));
create trigger patients_set_updated_at before update on public.patients for each row execute function public.set_updated_at();

create table if not exists public.patient_visits (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  visit_date date not null default current_date,
  treatment text not null default '',
  notes text not null default '',
  amount numeric(10,2) not null default 0,
  status text not null default 'completed',
  next_visit_date date,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists patient_visits_patient_idx on public.patient_visits (patient_id);
create index if not exists patient_visits_date_idx on public.patient_visits (visit_date);
grant select, insert, update, delete on public.patient_visits to authenticated;
grant all on public.patient_visits to service_role;
alter table public.patient_visits enable row level security;
create policy "Staff view visits" on public.patient_visits for select to authenticated using (public.staff_can(auth.uid(), 'patients_view'));
create policy "Staff add visits" on public.patient_visits for insert to authenticated with check (public.staff_can(auth.uid(), 'patients_edit'));
create policy "Staff update visits" on public.patient_visits for update to authenticated using (public.staff_can(auth.uid(), 'patients_edit')) with check (public.staff_can(auth.uid(), 'patients_edit'));
create policy "Admins delete visits" on public.patient_visits for delete to authenticated using (public.has_role(auth.uid(), 'admin'));
create trigger patient_visits_set_updated_at before update on public.patient_visits for each row execute function public.set_updated_at();

create table if not exists public.patient_files (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients(id) on delete cascade,
  storage_path text not null,
  label text not null default 'X-ray',
  file_type text not null default '',
  uploaded_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists patient_files_patient_idx on public.patient_files (patient_id);
grant select, insert, update, delete on public.patient_files to authenticated;
grant all on public.patient_files to service_role;
alter table public.patient_files enable row level security;
create policy "Staff view patient files" on public.patient_files for select to authenticated using (public.staff_can(auth.uid(), 'files'));
create policy "Staff add patient files" on public.patient_files for insert to authenticated with check (public.staff_can(auth.uid(), 'files'));
create policy "Staff delete patient files" on public.patient_files for delete to authenticated using (public.staff_can(auth.uid(), 'files'));

create table if not exists public.patient_messages (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.patients(id) on delete cascade,
  appointment_id uuid references public.appointments(id) on delete set null,
  kind text not null default 'reminder',
  channel text not null default 'whatsapp',
  body text not null default '',
  sent_by uuid,
  sent_at timestamptz not null default now()
);
create index if not exists patient_messages_patient_idx on public.patient_messages (patient_id);
grant select, insert, delete on public.patient_messages to authenticated;
grant all on public.patient_messages to service_role;
alter table public.patient_messages enable row level security;
create policy "Staff view messages" on public.patient_messages for select to authenticated using (public.staff_can(auth.uid(), 'messages'));
create policy "Staff log messages" on public.patient_messages for insert to authenticated with check (public.staff_can(auth.uid(), 'messages'));
create policy "Admins delete messages" on public.patient_messages for delete to authenticated using (public.has_role(auth.uid(), 'admin'));

-- approved staff with the bookings permission can also see/update website appointments
create policy "Staff view appointments" on public.appointments for select to authenticated using (public.staff_can(auth.uid(), 'appointments'));
create policy "Staff update appointments" on public.appointments for update to authenticated using (public.staff_can(auth.uid(), 'appointments')) with check (public.staff_can(auth.uid(), 'appointments'));
