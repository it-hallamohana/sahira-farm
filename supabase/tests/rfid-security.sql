-- Run against a disposable/local Supabase-compatible Postgres database.
-- Fixtures and credentials live inside a rolled-back transaction; nothing is printed.
begin;
create function pg_temp.expect_error(statement text,expected_code text) returns void language plpgsql as $$
declare actual text;
begin
 begin execute statement; exception when others then get stacked diagnostics actual=returned_sqlstate; end;
 if actual is distinct from expected_code then raise exception 'Expected SQLSTATE %, got % for %',expected_code,actual,statement; end if;
end; $$;
create temp table test_context(key text primary key,value jsonb);
grant all on test_context to authenticated,service_role;
insert into auth.users(id,email,email_confirmed_at) values
 ('11111111-1111-4111-8111-111111111111','rfid-admin@example.invalid',null),
 ('22222222-2222-4222-8222-222222222222','rfid-other@example.invalid',now());
insert into private.admin_allowlist(email) values('rfid-admin@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select pg_temp.expect_error('select public.claim_farm_admin()','42501');
select pg_temp.expect_error($q$select public.provision_rfid_device('Reader test','test-reader')$q$,'42501');
reset role;
update auth.users set email_confirmed_at=now() where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
do $$ begin if not public.claim_farm_admin() then raise exception 'Allowlisted verified account failed'; end if; end $$;
insert into test_context values('device',public.provision_rfid_device('Reader test','test-reader'));
insert into public.sheep(id,name,ear_tag,birth_date,sex,breed,health,barn) values
 ('33333333-3333-4333-8333-333333333333','Kambing A','TEST-001','2025-01-01','jantan','Boer 100%','Sehat','Test A'),
 ('44444444-4444-4444-8444-444444444444','Kambing B','TEST-002','2025-01-01','betina','Boer 100%','Sehat','Test A');
select pg_temp.expect_error('select * from private.device_credentials','42501');
select pg_temp.expect_error($q$insert into public.rfid_tags(owner_id,uid) values(auth.uid(),'040000AA')$q$,'42501');
select pg_temp.expect_error($q$select public.ingest_rfid_scan(gen_random_uuid(),'x',gen_random_uuid(),'040000AA',now(),'{}')$q$,'42501');
do $$ declare changed integer; begin
 update public.devices set revoked_at=now() where id=(select (value->>'device_id')::uuid from test_context where key='device');
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'Physical device was writable directly'; end if;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into test_context values('observed',to_jsonb(clock_timestamp()));
insert into test_context
select 'unknown',public.ingest_rfid_scan((value->>'device_id')::uuid,encode(sha256(convert_to(value->>'token','UTF8')),'hex'),
 '55555555-5555-4555-8555-555555555555','04:00:00:AA',(select (value#>>'{}')::timestamptz from test_context where key='observed'),'{"weight_kg":42.5}')
from test_context where key='device';
do $$ begin
 if (select value->>'status' from test_context where key='unknown')<>'pending' then raise exception 'Unknown scan not pending'; end if;
 if (select count(*) from public.sheep)<>2 then raise exception 'Unknown scan auto-created an animal'; end if;
 if exists(select 1 from public.sensor_readings) then raise exception 'Unknown scan was treated as animal measurement'; end if;
end $$;
insert into test_context
select 'duplicate',public.ingest_rfid_scan((value->>'device_id')::uuid,encode(sha256(convert_to(value->>'token','UTF8')),'hex'),
 '55555555-5555-4555-8555-555555555555','040000AA',(select (value#>>'{}')::timestamptz from test_context where key='observed'),'{"weight_kg":42.5}')
from test_context where key='device';
do $$ begin
 if (select value->>'duplicate' from test_context where key='duplicate')<>'true' then raise exception 'Replay not idempotent'; end if;
 if (select count(*) from public.rfid_scans)<>1 then raise exception 'Replay duplicated scan'; end if;
end $$;
select pg_temp.expect_error(format($q$select public.ingest_rfid_scan(%L::uuid,%L,%L::uuid,'040000AA',%L::timestamptz,'{"weight_kg":43}')$q$,
 value->>'device_id',encode(sha256(convert_to(value->>'token','UTF8')),'hex'),'55555555-5555-4555-8555-555555555555',
 (select value#>>'{}' from test_context where key='observed')),'23505') from test_context where key='device';
select pg_temp.expect_error(format($q$select public.ingest_rfid_scan(%L::uuid,%L,gen_random_uuid(),'040000AA',now(),'{}')$q$,
 value->>'device_id',repeat('0',64)),'28000') from test_context where key='device';
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into test_context
select 'tag',public.assign_rfid_tag('33333333-3333-4333-8333-333333333333','04-00-00-aa','Test tag',(value->>'id')::uuid,'Uji penautan') from test_context where key='unknown';
do $$ begin
 if exists(select 1 from public.rfid_scans where status<>'resolved' or sheep_id is not null) then raise exception 'Resolution rewrote historical animal association'; end if;
end $$;
select pg_temp.expect_error($q$select public.assign_rfid_tag('44444444-4444-4444-8444-444444444444','040000AA')$q$,'23505');
select pg_temp.expect_error($q$select public.assign_rfid_tag('33333333-3333-4333-8333-333333333333','040000BB')$q$,'23505');
reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into test_context
select 'known',public.ingest_rfid_scan((value->>'device_id')::uuid,encode(sha256(convert_to(value->>'token','UTF8')),'hex'),
 '66666666-6666-4666-8666-666666666666','040000AA',clock_timestamp(),'{"weight_kg":42.5}') from test_context where key='device';
do $$ begin
 if (select value->>'status' from test_context where key='known')<>'recognized' then raise exception 'Known scan not recognized'; end if;
 if (select count(*) from public.sensor_readings where not is_simulated and rfid_scan_id is not null)<>1 then raise exception 'Measurement missing or duplicated'; end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
select pg_temp.expect_error('select public.claim_farm_admin()','42501');
select pg_temp.expect_error($q$select public.assign_rfid_tag('33333333-3333-4333-8333-333333333333','040000DD')$q$,'42501');
do $$ begin
 if exists(select 1 from public.rfid_scans) or exists(select 1 from public.rfid_tags) then raise exception 'Cross-owner RFID data leaked'; end if;
end $$;
insert into public.sheep(id,name,ear_tag,birth_date,sex,breed,health,barn) values
 ('77777777-7777-4777-8777-777777777777','Other goat','TEST-003','2025-01-01','jantan','Boer 100%','Sehat','Other');
select pg_temp.expect_error($q$select public.assign_rfid_tag('77777777-7777-4777-8777-777777777777','040000AA')$q$,'42501');
select set_config('request.jwt.claims','{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select public.release_rfid_tag((value->>'tag_id')::uuid,'Tag diganti untuk pengujian') from test_context where key='tag';
do $$ declare result jsonb; begin
 result:=public.assign_rfid_tag('44444444-4444-4444-8444-444444444444','040000AA','',null,'Reassignment test');
 if (select count(*) from public.rfid_assignments)<>2 then raise exception 'Assignment history not preserved'; end if;
 if (select count(*) from public.rfid_assignments where ended_at is null)<>1 then raise exception 'Active assignment uniqueness broken'; end if;
end $$;
select public.revoke_rfid_device((value->>'device_id')::uuid) from test_context where key='device';
reset role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.expect_error(format($q$select public.ingest_rfid_scan(%L::uuid,%L,gen_random_uuid(),'040000AA',now(),'{}')$q$,
 value->>'device_id',encode(sha256(convert_to(value->>'token','UTF8')),'hex')),'28000') from test_context where key='device';
reset role;
select 'RFID security, isolation, idempotency, assignment history and revocation tests passed' as result;
rollback;
