-- HOME COACHING - database schema for Supabase
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'client' check (role in ('client','coach')),
  goal text,
  level text,
  created_at timestamptz not null default now()
);

create table if not exists public.weekly_workouts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  week_number integer not null,
  day_number integer not null check (day_number between 1 and 3),
  title text not null,
  duration_minutes integer not null default 50,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  unique(client_id, week_number, day_number)
);

create table if not exists public.workout_blocks (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.weekly_workouts(id) on delete cascade,
  sort_order integer not null,
  block_type text not null check (block_type in ('strength','core','wod','other')),
  title text not null,
  sets integer,
  rest_seconds integer,
  notes text
);

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  block_id uuid not null references public.workout_blocks(id) on delete cascade,
  sort_order integer not null,
  exercise_name text not null,
  reps_text text,
  duration_seconds integer,
  side text,
  video_url text,
  coach_notes text
);

create table if not exists public.workout_completions (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.weekly_workouts(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  completed_at timestamptz not null default now(),
  feeling text check (feeling in ('Difficile','Buono','Ottimo')),
  notes text,
  unique(workout_id, client_id)
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  week_number integer not null,
  feeling text,
  notes text,
  coach_reply text,
  created_at timestamptz not null default now(),
  replied_at timestamptz
);

create or replace function public.is_coach()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'coach'
  );
$$;

alter table public.profiles enable row level security;
alter table public.weekly_workouts enable row level security;
alter table public.workout_blocks enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_completions enable row level security;
alter table public.checkins enable row level security;

drop policy if exists "profiles own or coach" on public.profiles;
create policy "profiles own or coach" on public.profiles
for select using (id = auth.uid() or public.is_coach());

create policy "profiles self insert" on public.profiles
for insert with check (id = auth.uid());

create policy "profiles self update or coach" on public.profiles
for update using (id = auth.uid() or public.is_coach())
with check (id = auth.uid() or public.is_coach());

drop policy if exists "workouts client or coach" on public.weekly_workouts;
create policy "workouts client or coach" on public.weekly_workouts
for select using (client_id = auth.uid() or public.is_coach());
create policy "workouts coach insert" on public.weekly_workouts
for insert with check (public.is_coach());
create policy "workouts coach update" on public.weekly_workouts
for update using (public.is_coach()) with check (public.is_coach());
create policy "workouts coach delete" on public.weekly_workouts
for delete using (public.is_coach());

drop policy if exists "blocks client or coach" on public.workout_blocks;
create policy "blocks client or coach" on public.workout_blocks
for select using (public.is_coach() or exists (select 1 from public.weekly_workouts w where w.id=workout_id and w.client_id=auth.uid() and w.published=true));
create policy "blocks coach write" on public.workout_blocks
for all using (public.is_coach()) with check (public.is_coach());

drop policy if exists "exercises client or coach" on public.workout_exercises;
create policy "exercises client or coach" on public.workout_exercises
for select using (public.is_coach() or exists (
  select 1 from public.workout_blocks b join public.weekly_workouts w on w.id=b.workout_id
  where b.id=block_id and w.client_id=auth.uid() and w.published=true
));
create policy "exercises coach write" on public.workout_exercises
for all using (public.is_coach()) with check (public.is_coach());

drop policy if exists "completions own or coach" on public.workout_completions;
create policy "completions own or coach" on public.workout_completions
for select using (client_id = auth.uid() or public.is_coach());
create policy "completions own insert" on public.workout_completions
for insert with check (client_id = auth.uid());
create policy "completions own update or coach" on public.workout_completions
for update using (client_id = auth.uid() or public.is_coach()) with check (client_id = auth.uid() or public.is_coach());

create policy "checkins own or coach" on public.checkins
for select using (client_id = auth.uid() or public.is_coach());
create policy "checkins own insert" on public.checkins
for insert with check (client_id = auth.uid());
create policy "checkins coach reply" on public.checkins
for update using (public.is_coach()) with check (public.is_coach());

-- Optional trigger: automatically create a client profile from Auth metadata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, goal, level)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name','Nuovo cliente'),
    new.raw_user_meta_data->>'goal',
    new.raw_user_meta_data->>'level'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- After creating your own account, promote it to coach manually:
-- update public.profiles set role='coach' where id = 'YOUR_USER_UUID';
