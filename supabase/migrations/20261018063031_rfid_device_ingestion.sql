begin;

-- Existing sheep identifiers remain stable; the product calls these records kambing.
insert into public.breeds(name,description) values
 ('Boer','Ras kambing pedaging'),('Peranakan Etawa','Kambing peranakan Etawa'),
 ('Kacang','Kambing lokal Indonesia'),('Sapera','Persilangan Saanen dan Peranakan Etawa')
on conflict(name) do nothing;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;
revoke create on schema public from public, anon, authenticated;

-- Keep privilege-bearing helpers outside the Data API schema.
alter function public.is_admin() set schema private;
create function public.is_admin() returns boolean language sql stable security invoker
set search_path='' as $$ select private.is_admin(); $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon,authenticated,service_role;
grant usage on schema private to anon;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to anon,authenticated,service_role;
create or replace function private.is_admin() returns boolean language sql stable security definer
set search_path='' as $$ select (select auth.uid()) is not null and exists(
 select 1 from public.user_roles where user_id=(select auth.uid()) and role='admin'); $$;

alter function public.save_home_content(jsonb,boolean) set schema private;
create function public.save_home_content(payload jsonb,publish_now boolean default false)
returns uuid language sql security invoker set search_path=''
as $$ select private.save_home_content(payload,publish_now); $$;
revoke all on function public.save_home_content(jsonb,boolean) from public;
grant execute on function public.save_home_content(jsonb,boolean) to authenticated;
revoke all on function private.save_home_content(jsonb,boolean) from public,anon;
grant execute on function private.save_home_content(jsonb,boolean) to authenticated;
alter function public.new_profile() set schema private;
revoke all on function private.new_profile() from public,anon,authenticated;

-- Explicit grants work even when the project's default Data API grants are disabled.
grant select on public.breeds,public.pages,public.content_versions,public.sections,
 public.content_blocks,public.site_settings to anon,authenticated;
grant select on public.profiles,public.user_roles to authenticated;
grant update(display_name) on public.profiles to authenticated;
grant select,insert,update,delete on public.barns,public.sheep,public.sheep_breed_compositions,
 public.growth_records,public.treatment_records,public.feeding_records,public.devices,
 public.sensors,public.device_assignments,public.sensor_readings,public.ml_predictions,
 public.breeds,public.pages,public.content_versions,public.sections,public.content_blocks,
 public.media_assets,public.site_settings to authenticated;
grant all on all tables in schema public to service_role;

alter table public.devices add column revoked_at timestamptz,
 add column last_seen_at timestamptz, add column firmware_version text;

create table private.device_credentials (
 device_id uuid primary key references public.devices(id) on delete cascade,
 token_hash text not null check(token_hash ~ '^[a-f0-9]{64}$'),
 created_at timestamptz not null default now(),
 minute_start timestamptz not null default now(), minute_count integer not null default 0
);
alter table private.device_credentials enable row level security;
revoke all on private.device_credentials from public,anon,authenticated;

create table private.admin_allowlist (
 email text primary key check(email=lower(trim(email)) and position('@' in email)>1),
 created_at timestamptz not null default now()
);
alter table private.admin_allowlist enable row level security;
revoke all on private.admin_allowlist from public,anon,authenticated;
grant select,insert,update,delete on private.admin_allowlist to service_role;
create function private.claim_farm_admin() returns boolean
language plpgsql security definer set search_path='' as $$
declare account auth.users;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='Sesi akun diperlukan.'; end if;
 select * into account from auth.users where id=auth.uid();
 if not found or account.email_confirmed_at is null or not exists(
  select 1 from private.admin_allowlist a where a.email=lower(trim(account.email))) then
  raise exception using errcode='42501',message='Email belum terverifikasi atau belum diberi akses pengelola.';
 end if;
 insert into public.user_roles(user_id,role) values(account.id,'admin') on conflict do nothing;
 return true;
end; $$;
create function public.claim_farm_admin() returns boolean language sql security invoker
set search_path='' as $$ select private.claim_farm_admin(); $$;
revoke all on function private.claim_farm_admin(),public.claim_farm_admin() from public,anon,authenticated;
grant execute on function private.claim_farm_admin(),public.claim_farm_admin() to authenticated;

create table public.rfid_tags (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 uid text not null unique check(uid ~ '^[0-9A-F]{4,64}$'),
 label text not null default '' check(length(label)<=100),
 created_at timestamptz not null default now(), unique(id,owner_id)
);
create table public.rfid_assignments (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null,
 tag_id uuid not null, sheep_id uuid not null,
 assigned_at timestamptz not null default clock_timestamp(), ended_at timestamptz,
 assigned_by uuid references auth.users(id) on delete set null,
 ended_by uuid references auth.users(id) on delete set null,
 reason text not null check(length(trim(reason)) between 3 and 500), end_reason text,
 foreign key(tag_id,owner_id) references public.rfid_tags(id,owner_id),
 foreign key(sheep_id,owner_id) references public.sheep(id,owner_id),
 check(ended_at is null or ended_at>=assigned_at)
);
create unique index rfid_one_active_tag on public.rfid_assignments(tag_id) where ended_at is null;
create unique index rfid_one_active_animal on public.rfid_assignments(sheep_id) where ended_at is null;
create index rfid_assignment_owner_idx on public.rfid_assignments(owner_id,assigned_at desc);
create index rfid_assignment_animal_history_idx on public.rfid_assignments(sheep_id,assigned_at desc);
create index rfid_tags_owner_idx on public.rfid_tags(owner_id);

create table public.rfid_scans (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null,
 device_id uuid not null, event_id uuid not null,
 uid text not null check(uid ~ '^[0-9A-F]{4,64}$'),
 sheep_id uuid, assignment_id uuid references public.rfid_assignments(id),
 observed_at timestamptz not null, received_at timestamptz not null default now(),
 status text not null check(status in ('pending','recognized','resolved','ignored')),
 payload jsonb not null default '{}' check(jsonb_typeof(payload)='object'),
 request_hash text not null,
 resolved_at timestamptz, resolved_by uuid references auth.users(id) on delete set null,
 resolution_note text,
 foreign key(device_id,owner_id) references public.devices(id,owner_id),
 foreign key(sheep_id,owner_id) references public.sheep(id,owner_id),
 unique(device_id,event_id)
);
create index rfid_scan_inbox_idx on public.rfid_scans(owner_id,received_at desc) where status='pending';
create index rfid_scan_owner_idx on public.rfid_scans(owner_id,received_at desc);
create index rfid_scan_animal_idx on public.rfid_scans(sheep_id,observed_at desc);
create index rfid_scan_assignment_idx on public.rfid_scans(assignment_id);
alter table public.sensor_readings add column rfid_scan_id uuid references public.rfid_scans(id);
create unique index reading_rfid_once on public.sensor_readings(rfid_scan_id) where rfid_scan_id is not null;

alter table public.rfid_tags enable row level security;
alter table public.rfid_assignments enable row level security;
alter table public.rfid_scans enable row level security;
create policy rfid_tag_read on public.rfid_tags for select to authenticated
 using(owner_id=(select auth.uid()) or (select public.is_admin()));
create policy rfid_assignment_read on public.rfid_assignments for select to authenticated
 using(owner_id=(select auth.uid()) or (select public.is_admin()));
create policy rfid_scan_read on public.rfid_scans for select to authenticated
 using(owner_id=(select auth.uid()) or (select public.is_admin()));
revoke all on public.rfid_tags,public.rfid_assignments,public.rfid_scans from anon,authenticated;
grant select on public.rfid_tags,public.rfid_assignments,public.rfid_scans to authenticated;
grant all on public.rfid_tags,public.rfid_assignments,public.rfid_scans to service_role;

-- Physical device identity, revocation and telemetry can only be changed by the backend.
drop policy owner_access on public.devices;
create policy device_read on public.devices for select to authenticated
 using(owner_id=(select auth.uid()) or (select public.is_admin()));
create policy simulator_insert on public.devices for insert to authenticated
 with check(owner_id=(select auth.uid()) and is_simulator and revoked_at is null);
create policy simulator_update on public.devices for update to authenticated
 using(owner_id=(select auth.uid()) and is_simulator)
 with check(owner_id=(select auth.uid()) and is_simulator and revoked_at is null);
create policy simulator_delete on public.devices for delete to authenticated
 using(owner_id=(select auth.uid()) and is_simulator);
drop policy owner_access on public.sensor_readings;
create policy reading_read on public.sensor_readings for select to authenticated
 using(owner_id=(select auth.uid()) or (select public.is_admin()));
create policy simulated_reading_write on public.sensor_readings for all to authenticated
 using(owner_id=(select auth.uid()) and is_simulated and rfid_scan_id is null
 and exists(select 1 from public.devices d where d.id=device_id and d.is_simulator))
 with check(owner_id=(select auth.uid()) and is_simulated and rfid_scan_id is null
 and exists(select 1 from public.devices d where d.id=device_id and d.is_simulator));

create function private.normalize_rfid_uid(p_uid text) returns text
language plpgsql immutable security invoker set search_path='' as $$
declare result text;
begin
 if p_uid is null or length(p_uid)>128 or p_uid !~ '^[0-9A-Fa-f :\t\r\n-]+$' then
  raise exception using errcode='22023',message='UID harus berupa karakter heksadesimal/angka, tanpa prefix.';
 end if;
 result:=upper(regexp_replace(p_uid,'[[:space:]:-]','','g'));
 if result !~ '^[0-9A-F]{4,64}$' then raise exception using errcode='22023',message='Panjang UID harus 4–64 karakter.'; end if;
 return result;
end; $$;

create function private.assert_rfid_owner(p_owner uuid) returns void
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or (auth.uid()<>p_owner and not private.is_admin()) then
  raise exception using errcode='42501',message='Akses peternakan ditolak.';
 end if;
end; $$;

create function private.provision_rfid_device(p_name text,p_external_id text,p_owner_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare new_device uuid; target_owner uuid:=coalesce(p_owner_id,auth.uid()); secret text;
begin
 if auth.uid() is null or not private.is_admin() then raise exception using errcode='42501',message='Hanya admin dapat mendaftarkan perangkat fisik.'; end if;
 if p_name is null or length(trim(p_name)) not between 2 and 100 or p_external_id is null
  or p_external_id !~ '^[A-Za-z0-9_-]{3,80}$' then
  raise exception using errcode='22023',message='Nama atau identitas perangkat tidak valid.';
 end if;
 secret:='rfid_'||replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into public.devices(owner_id,name,external_id,is_simulator)
 values(target_owner,trim(p_name),p_external_id,false) returning id into new_device;
 insert into private.device_credentials(device_id,token_hash)
 values(new_device,encode(sha256(convert_to(secret,'UTF8')),'hex'));
 return jsonb_build_object('device_id',new_device,'external_id',p_external_id,'token',secret);
end; $$;

create function private.assign_rfid_tag(p_sheep_id uuid,p_uid text,p_label text default '',
 p_scan_id uuid default null,p_reason text default 'Pendaftaran awal')
returns jsonb language plpgsql security definer set search_path='' as $$
declare animal public.sheep; tag public.rfid_tags; assignment_uuid uuid;
 normalized text:=private.normalize_rfid_uid(p_uid); scan public.rfid_scans;
begin
 select * into animal from public.sheep where id=p_sheep_id for update;
 if not found then raise exception using errcode='22023',message='Data kambing tidak ditemukan.'; end if;
 perform private.assert_rfid_owner(animal.owner_id);
 if not animal.active then raise exception using errcode='22023',message='Tag hanya dapat dipasang pada kambing aktif.'; end if;
 if p_label is null or length(p_label)>100 or p_reason is null or length(trim(p_reason)) not between 3 and 500 then
  raise exception using errcode='22023',message='Label atau alasan penautan tidak valid.';
 end if;
 -- Serialize operations on a UID, including the first registration before a row exists.
 perform pg_advisory_xact_lock(hashtextextended('rfid:'||normalized,0));
 select * into tag from public.rfid_tags where uid=normalized for update;
 if found and tag.owner_id<>animal.owner_id then raise exception using errcode='42501',message='Tag ini tidak tersedia untuk peternakan Anda.'; end if;
 if exists(select 1 from public.rfid_assignments where ended_at is null and (sheep_id=p_sheep_id or tag_id=tag.id)) then
  raise exception using errcode='23505',message='Kambing atau tag sudah memiliki pasangan aktif. Lepaskan tag lama dengan alasan terlebih dahulu.';
 end if;
 if tag.id is null then
  insert into public.rfid_tags(owner_id,uid,label) values(animal.owner_id,normalized,p_label) returning * into tag;
 end if;
 if p_scan_id is not null then
  select * into scan from public.rfid_scans where id=p_scan_id for update;
  if not found or scan.owner_id<>animal.owner_id or scan.uid<>normalized or scan.status<>'pending' then
   raise exception using errcode='22023',message='Pemindaian tidak cocok atau sudah ditindaklanjuti.';
  end if;
 end if;
 insert into public.rfid_assignments(owner_id,tag_id,sheep_id,assigned_by,reason)
 values(animal.owner_id,tag.id,p_sheep_id,auth.uid(),trim(p_reason)) returning id into assignment_uuid;
 if p_scan_id is not null then
  update public.rfid_scans set status='resolved',resolved_at=now(),resolved_by=auth.uid(),
   resolution_note='Ditautkan ke kambing '||animal.ear_tag||'. '||trim(p_reason)
  where id=p_scan_id;
 end if;
 return jsonb_build_object('tag_id',tag.id,'assignment_id',assignment_uuid,'uid',normalized,'sheep_id',p_sheep_id);
end; $$;

create function private.release_rfid_tag(p_tag_id uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare tag public.rfid_tags;
begin
 select * into tag from public.rfid_tags where id=p_tag_id;
 if not found then raise exception using errcode='22023',message='Tag tidak ditemukan.'; end if;
 perform private.assert_rfid_owner(tag.owner_id);
 if p_reason is null or length(trim(p_reason)) not between 3 and 500 then raise exception using errcode='22023',message='Tuliskan alasan pelepasan tag (3–500 karakter).'; end if;
 perform pg_advisory_xact_lock(hashtextextended('rfid:'||tag.uid,0));
 update public.rfid_assignments set ended_at=clock_timestamp(),ended_by=auth.uid(),end_reason=trim(p_reason)
 where tag_id=p_tag_id and ended_at is null;
 if not found then raise exception using errcode='22023',message='Tag tidak memiliki pasangan aktif.'; end if;
end; $$;

create function private.revoke_rfid_device(p_device_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not private.is_admin() then raise exception using errcode='42501',message='Hanya admin dapat mencabut akses perangkat.'; end if;
 update public.devices set revoked_at=coalesce(revoked_at,now()) where id=p_device_id and not is_simulator;
 if not found then raise exception using errcode='22023',message='Perangkat fisik tidak ditemukan.'; end if;
end; $$;

create function private.dismiss_rfid_scan(p_scan_id uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare scan public.rfid_scans;
begin
 select * into scan from public.rfid_scans where id=p_scan_id for update;
 if not found then raise exception using errcode='22023',message='Pemindaian tidak ditemukan.'; end if;
 perform private.assert_rfid_owner(scan.owner_id);
 if p_reason is null or length(trim(p_reason)) not between 3 and 500 then raise exception using errcode='22023',message='Tuliskan alasan pengabaian.'; end if;
 if scan.status<>'pending' then raise exception using errcode='22023',message='Pemindaian sudah ditindaklanjuti.'; end if;
 update public.rfid_scans set status='ignored',resolved_at=now(),resolved_by=auth.uid(),resolution_note=trim(p_reason) where id=p_scan_id;
end; $$;

-- Only the ingestion Edge Function's service role can call this operation.
create function private.ingest_rfid_scan(p_device_id uuid,p_token_hash text,p_event_id uuid,
 p_uid text,p_observed_at timestamptz,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare device public.devices; credential private.device_credentials; existing public.rfid_scans;
 current_assignment public.rfid_assignments; normalized text:=private.normalize_rfid_uid(p_uid);
 content_hash text; scan_uuid uuid; scan_status text; weight numeric; new_minute timestamptz:=date_trunc('minute',now());
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception using errcode='42501',message='Backend ingestion only.'; end if;
 select * into device from public.devices where id=p_device_id for update;
 select * into credential from private.device_credentials where device_id=p_device_id for update;
 if device.id is null or credential.device_id is null or device.is_simulator or device.revoked_at is not null
  or p_token_hash is null or credential.token_hash<>p_token_hash then
  raise exception using errcode='28000',message='Perangkat atau kredensial tidak valid.';
 end if;
 if p_event_id is null or p_observed_at is null or p_observed_at>now()+interval '5 minutes'
  or p_observed_at<now()-interval '30 days' or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>4096 then
  raise exception using errcode='22023',message='Payload atau waktu pemindaian tidak valid.';
 end if;
 if p_payload ? 'weight_kg' then
  if jsonb_typeof(p_payload->'weight_kg')<>'number' then raise exception using errcode='22023',message='Bobot harus angka.'; end if;
  weight:=(p_payload->>'weight_kg')::numeric;
  if weight<=0 or weight>250 then raise exception using errcode='22023',message='Bobot harus lebih dari 0 sampai 250 kg.'; end if;
 end if;
 content_hash:=encode(sha256(convert_to(jsonb_build_object('uid',normalized,'observed_at',p_observed_at,'payload',p_payload)::text,'UTF8')),'hex');
 select * into existing from public.rfid_scans where device_id=p_device_id and event_id=p_event_id;
 if found then
  if existing.request_hash<>content_hash then raise exception using errcode='23505',message='event_id sudah digunakan untuk isi yang berbeda.'; end if;
  return jsonb_build_object('id',existing.id,'status',existing.status,'sheep_id',existing.sheep_id,'duplicate',true);
 end if;
 if credential.minute_start=new_minute and credential.minute_count>=120 then
  raise exception using errcode='P0001',message='DEVICE_RATE_LIMIT';
 end if;
 update private.device_credentials set minute_start=new_minute,
  minute_count=case when minute_start=new_minute then minute_count+1 else 1 end where device_id=p_device_id;
 -- Match the assignment at measurement time, so offline events retain historical ownership.
 select a.* into current_assignment from public.rfid_assignments a join public.rfid_tags t on t.id=a.tag_id
 where t.uid=normalized and a.owner_id=device.owner_id and a.assigned_at<=p_observed_at
  and (a.ended_at is null or a.ended_at>p_observed_at)
 order by a.assigned_at desc limit 1;
 scan_status:=case when current_assignment.id is null then 'pending' else 'recognized' end;
 insert into public.rfid_scans(owner_id,device_id,event_id,uid,sheep_id,assignment_id,observed_at,status,payload,request_hash)
 values(device.owner_id,device.id,p_event_id,normalized,current_assignment.sheep_id,current_assignment.id,
  p_observed_at,scan_status,p_payload,content_hash) returning id into scan_uuid;
 if weight is not null and current_assignment.id is not null then
  insert into public.sensor_readings(owner_id,device_id,recorded_at,value,unit,is_simulated,rfid_scan_id)
  values(device.owner_id,device.id,p_observed_at,weight,'kg',false,scan_uuid);
 end if;
 update public.devices set last_seen_at=now(),firmware_version=coalesce(p_payload->>'firmware_version',firmware_version) where id=device.id;
 return jsonb_build_object('id',scan_uuid,'status',scan_status,'sheep_id',current_assignment.sheep_id,'duplicate',false);
end; $$;

-- Public RPCs are SECURITY INVOKER entry points; only narrowly granted private helpers elevate.
create function public.provision_rfid_device(p_name text,p_external_id text,p_owner_id uuid default null)
returns jsonb language sql security invoker set search_path='' as $$ select private.provision_rfid_device(p_name,p_external_id,p_owner_id); $$;
create function public.assign_rfid_tag(p_sheep_id uuid,p_uid text,p_label text default '',p_scan_id uuid default null,p_reason text default 'Pendaftaran awal')
returns jsonb language sql security invoker set search_path='' as $$ select private.assign_rfid_tag(p_sheep_id,p_uid,p_label,p_scan_id,p_reason); $$;
create function public.release_rfid_tag(p_tag_id uuid,p_reason text) returns void language sql security invoker set search_path='' as $$ select private.release_rfid_tag(p_tag_id,p_reason); $$;
create function public.revoke_rfid_device(p_device_id uuid) returns void language sql security invoker set search_path='' as $$ select private.revoke_rfid_device(p_device_id); $$;
create function public.dismiss_rfid_scan(p_scan_id uuid,p_reason text) returns void language sql security invoker set search_path='' as $$ select private.dismiss_rfid_scan(p_scan_id,p_reason); $$;
create function public.ingest_rfid_scan(p_device_id uuid,p_token_hash text,p_event_id uuid,p_uid text,p_observed_at timestamptz,p_payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$ select private.ingest_rfid_scan(p_device_id,p_token_hash,p_event_id,p_uid,p_observed_at,p_payload); $$;

revoke all on function private.normalize_rfid_uid(text),private.assert_rfid_owner(uuid),
 private.provision_rfid_device(text,text,uuid),private.assign_rfid_tag(uuid,text,text,uuid,text),
 private.release_rfid_tag(uuid,text),private.revoke_rfid_device(uuid),private.dismiss_rfid_scan(uuid,text),
 private.ingest_rfid_scan(uuid,text,uuid,text,timestamptz,jsonb),
 public.provision_rfid_device(text,text,uuid),public.assign_rfid_tag(uuid,text,text,uuid,text),
 public.release_rfid_tag(uuid,text),public.revoke_rfid_device(uuid),public.dismiss_rfid_scan(uuid,text),
 public.ingest_rfid_scan(uuid,text,uuid,text,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function private.provision_rfid_device(text,text,uuid),private.assign_rfid_tag(uuid,text,text,uuid,text),
 private.release_rfid_tag(uuid,text),private.revoke_rfid_device(uuid),private.dismiss_rfid_scan(uuid,text),
 public.provision_rfid_device(text,text,uuid),public.assign_rfid_tag(uuid,text,text,uuid,text),
 public.release_rfid_tag(uuid,text),public.revoke_rfid_device(uuid),public.dismiss_rfid_scan(uuid,text) to authenticated;
grant execute on function private.ingest_rfid_scan(uuid,text,uuid,text,timestamptz,jsonb),
 public.ingest_rfid_scan(uuid,text,uuid,text,timestamptz,jsonb) to service_role;

comment on table private.device_credentials is 'SHA-256 hashes only. Raw credentials returned once at provisioning, never stored.';
comment on table public.rfid_scans is 'Immutable event identity. Unknown UID never creates animals. Resolution does not rewrite historical association.';
comment on column public.rfid_scans.sheep_id is 'Animal resolved at observed_at, not current tag ownership.';
commit;
