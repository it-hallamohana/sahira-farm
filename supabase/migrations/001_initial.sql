begin;
create table public.profiles (id uuid primary key references auth.users on delete cascade, display_name text not null default '', created_at timestamptz not null default now());
create table public.user_roles (user_id uuid not null references auth.users on delete cascade, role text not null check(role in ('admin','farmer')), primary key(user_id,role));
create function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.user_roles where user_id=auth.uid() and role='admin'); $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon,authenticated;
create function public.new_profile() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name','')); insert into user_roles values(new.id,'farmer'); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.new_profile();
create table public.barns (id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users on delete cascade, name text not null, capacity integer check(capacity>0), unique(id,owner_id),unique(owner_id,name));
create table public.breeds (id uuid primary key default gen_random_uuid(), name text not null unique, description text not null default '');
create table public.sheep (id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users on delete cascade, name text not null check(length(name)>=2), ear_tag text not null, birth_date date not null check(birth_date<=current_date), sex text not null check(sex in ('jantan','betina')), breed text not null, health text not null, barn text not null, barn_id uuid, active boolean not null default true, photo text not null default '', sire_id uuid, dam_id uuid, created_at timestamptz not null default now(), unique(id,owner_id),unique(owner_id,ear_tag),check(sire_id is null or sire_id<>id),check(dam_id is null or dam_id<>id),foreign key(sire_id,owner_id) references sheep(id,owner_id),foreign key(dam_id,owner_id) references sheep(id,owner_id),foreign key(barn_id,owner_id) references barns(id,owner_id));
create table public.sheep_breed_compositions (sheep_id uuid not null, owner_id uuid not null default auth.uid(), breed_id uuid not null references breeds, percentage numeric(5,2) not null check(percentage>0 and percentage<=100), primary key(sheep_id,breed_id), foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade);
create table public.growth_records (id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid(), sheep_id uuid not null, date date not null check(date<=current_date), weight numeric(6,2) not null check(weight>0 and weight<=250),height numeric(6,2) not null check(height>0 and height<=200),notes text not null default '',foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade,unique(sheep_id,date));
create table public.treatment_records (id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid(),sheep_id uuid not null,date date not null check(date<=current_date),kind text not null check(kind in ('Pakan','Vitamin','Vaksinasi','Pemeriksaan kesehatan','Perlakuan lain')),notes text not null,foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade);
create table public.feeding_records (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid(),sheep_id uuid not null,date date not null,feed_type text not null,amount_kg numeric not null check(amount_kg>0),notes text,foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade);
create table public.devices (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid() references auth.users on delete cascade,name text not null,sheep_id uuid,external_id text unique,is_simulator boolean not null default true,unique(id,owner_id),foreign key(sheep_id,owner_id) references sheep(id,owner_id));
create table public.sensors (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid(),device_id uuid not null,kind text not null,unit text not null,unique(id,owner_id),foreign key(device_id,owner_id) references devices(id,owner_id) on delete cascade);
create table public.device_assignments (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid(),device_id uuid not null,sheep_id uuid not null,started_at timestamptz not null default now(),ended_at timestamptz,check(ended_at is null or ended_at>started_at),foreign key(device_id,owner_id) references devices(id,owner_id) on delete cascade,foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade);
create unique index device_one_current_assignment on device_assignments(device_id) where ended_at is null;
create table public.sensor_readings (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid(),device_id uuid not null,sensor_id uuid,recorded_at timestamptz not null default now(),value numeric not null,unit text not null,is_simulated boolean not null default true,foreign key(device_id,owner_id) references devices(id,owner_id) on delete cascade,foreign key(sensor_id,owner_id) references sensors(id,owner_id));
create table public.ml_predictions (id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid(),sheep_id uuid not null,score numeric check(score>=0 and score<=1),model_version text not null,is_demo boolean not null default true,factors jsonb not null default '{}',created_at timestamptz not null default now(),foreign key(sheep_id,owner_id) references sheep(id,owner_id) on delete cascade);
create table public.pages (id text primary key,slug text not null unique,title text not null);
create table public.content_versions (id uuid primary key default gen_random_uuid(),page_id text not null references pages on delete cascade,status text not null check(status in ('draft','published','archived')),content jsonb not null,created_by uuid references auth.users,created_at timestamptz not null default now());
create unique index one_published_version on content_versions(page_id) where status='published';
create table public.sections (id uuid primary key default gen_random_uuid(),version_id uuid not null references content_versions on delete cascade,section_key text not null,kind text not null,position integer not null,visible boolean not null default true,unique(version_id,section_key));
create table public.content_blocks (id uuid primary key default gen_random_uuid(),section_id uuid not null references sections on delete cascade,block_key text not null,payload jsonb not null,unique(section_id,block_key));
create table public.media_assets (id uuid primary key default gen_random_uuid(),path text not null unique,mime_type text not null,size bigint not null check(size>0 and size<=5242880),uploaded_by uuid not null default auth.uid() references auth.users,created_at timestamptz not null default now());
create table public.site_settings (key text primary key,value jsonb not null,is_public boolean not null default false);

create index sheep_owner_idx on sheep(owner_id);
create index sheep_sire_idx on sheep(sire_id);
create index sheep_dam_idx on sheep(dam_id);
create index growth_owner_date_idx on growth_records(owner_id,sheep_id,date);
create index treatment_owner_date_idx on treatment_records(owner_id,sheep_id,date);
create index readings_device_time_idx on sensor_readings(owner_id,device_id,recorded_at desc);
create index content_version_idx on content_versions(page_id,status,created_at desc);
do $$ declare t text; begin
 foreach t in array array['barns','sheep','sheep_breed_compositions','growth_records','treatment_records','feeding_records','devices','sensors','device_assignments','sensor_readings','ml_predictions'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy owner_access on public.%I for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid())',t);
 end loop;
 foreach t in array array['profiles','user_roles','breeds','pages','content_versions','sections','content_blocks','media_assets','site_settings'] loop execute format('alter table public.%I enable row level security',t); end loop;
end $$;
create policy self_profile on profiles for select to authenticated using(id=auth.uid() or is_admin());
create policy update_profile on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy role_read on user_roles for select to authenticated using(user_id=auth.uid() or is_admin());
-- Role assignment is intentionally SQL/service-side only. Browser users cannot promote themselves.
create policy breed_read on breeds for select to anon,authenticated using(true);
create policy breed_admin on breeds for all to authenticated using(is_admin()) with check(is_admin());
create policy page_read on pages for select to anon,authenticated using(exists(select 1 from content_versions v where v.page_id=pages.id and v.status='published') or is_admin());
create policy page_admin on pages for all to authenticated using(is_admin()) with check(is_admin());
create policy version_read on content_versions for select to anon,authenticated using(status='published' or is_admin());
create policy version_admin on content_versions for all to authenticated using(is_admin()) with check(is_admin());
create policy section_read on sections for select to anon,authenticated using(exists(select 1 from content_versions v where v.id=version_id and v.status='published') or is_admin());
create policy section_admin on sections for all to authenticated using(is_admin()) with check(is_admin());
create policy block_read on content_blocks for select to anon,authenticated using(exists(select 1 from sections s join content_versions v on v.id=s.version_id where s.id=section_id and v.status='published') or is_admin());
create policy block_admin on content_blocks for all to authenticated using(is_admin()) with check(is_admin());
create policy media_admin on media_assets for all to authenticated using(is_admin() or uploaded_by=auth.uid()) with check(uploaded_by=auth.uid());
create policy public_settings on site_settings for select to anon,authenticated using(is_public or is_admin());
create policy admin_settings on site_settings for all to authenticated using(is_admin()) with check(is_admin());

create function public.save_home_content(payload jsonb,publish_now boolean default false) returns uuid language plpgsql security definer set search_path=public as $$
declare version_uuid uuid; section_uuid uuid; item jsonb; i integer:=0; field text;
begin
 if not is_admin() then raise exception 'Admin role required'; end if;
 if jsonb_typeof(payload->'sections')<>'array' or length(payload->>'seoTitle')<3 then raise exception 'Invalid content';end if;
 perform pg_advisory_xact_lock(hashtext('home-content-publish'));
 if publish_now then update content_versions set status='archived' where page_id='home' and status='published';end if;
 insert into content_versions(page_id,status,content,created_by) values('home',case when publish_now then 'published' else 'draft' end,payload,auth.uid()) returning id into version_uuid;
 for item in select value from jsonb_array_elements(payload->'sections') loop
 insert into sections(version_id,section_key,kind,position,visible) values(version_uuid,item->>'id',item->>'kind',i,(item->>'visible')::boolean) returning id into section_uuid;
 foreach field in array array['label','title','text','image','button','url','items'] loop insert into content_blocks(section_id,block_key,payload) values(section_uuid,field,coalesce(item->field,'null'::jsonb));end loop;
 i:=i+1;
 end loop;
 return version_uuid;
end; $$;
revoke all on function public.save_home_content(jsonb,boolean) from public;
grant execute on function public.save_home_content(jsonb,boolean) to authenticated;

create function public.validate_sheep_parents() returns trigger language plpgsql set search_path=public as $$
declare parent sheep; has_cycle boolean;
begin
 if new.sire_id is not null then select * into parent from sheep where id=new.sire_id and owner_id=new.owner_id; if parent.sex<>'jantan' or parent.birth_date>=new.birth_date then raise exception 'Induk jantan harus jantan dan lebih tua'; end if; end if;
 if new.dam_id is not null then select * into parent from sheep where id=new.dam_id and owner_id=new.owner_id; if parent.sex<>'betina' or parent.birth_date>=new.birth_date then raise exception 'Induk betina harus betina dan lebih tua'; end if; end if;
 with recursive ancestors(id,sire_id,dam_id) as (select id,sire_id,dam_id from sheep where id in (new.sire_id,new.dam_id) union select s.id,s.sire_id,s.dam_id from sheep s join ancestors a on s.id in(a.sire_id,a.dam_id)) select exists(select 1 from ancestors where id=new.id) into has_cycle;
 if has_cycle then raise exception 'Silsilah tidak boleh membentuk siklus';end if;
 if exists(select 1 from sheep s where (s.sire_id=new.id and (new.sex<>'jantan' or new.birth_date>=s.birth_date)) or (s.dam_id=new.id and (new.sex<>'betina' or new.birth_date>=s.birth_date))) then raise exception 'Perubahan bertentangan dengan data keturunan';end if;
 if exists(select 1 from growth_records g where g.sheep_id=new.id and g.date<new.birth_date) then raise exception 'Tanggal lahir melewati tanggal pengukuran'; end if;
 return new;
end; $$;
create trigger sheep_parent_guard before insert or update on sheep for each row execute function validate_sheep_parents();
create function public.validate_growth_date() returns trigger language plpgsql set search_path=public as $$ begin if new.date<(select birth_date from sheep where id=new.sheep_id and owner_id=new.owner_id) then raise exception 'Tanggal pengukuran sebelum tanggal lahir';end if;return new;end; $$;
create trigger growth_date_guard before insert or update on growth_records for each row execute function validate_growth_date();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('media','media',true,5242880,array['image/jpeg','image/png','image/webp','image/avif']) on conflict(id) do nothing;
create policy image_upload on storage.objects for insert to authenticated with check(bucket_id='media' and owner_id=auth.uid()::text);
create policy image_owner_delete on storage.objects for delete to authenticated using(bucket_id='media' and owner_id=auth.uid()::text);
create policy image_read on storage.objects for select to anon,authenticated using(bucket_id='media');
commit;
