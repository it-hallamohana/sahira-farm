begin;
-- Keep the readable profile field and normalized breed/barn tables in sync.
create function public.sync_sheep_details() returns trigger language plpgsql set search_path=public as $$
declare part text; matched text[]; breed_uuid uuid; total numeric:=0; seen uuid[]:='{}';
begin
 insert into barns(owner_id,name) values(new.owner_id,new.barn) on conflict(owner_id,name) do update set name=excluded.name returning id into new.barn_id;
 return new;
end; $$;
create trigger sheep_barn_sync before insert or update of barn on sheep for each row execute function sync_sheep_details();
create function public.sync_breed_compositions() returns trigger language plpgsql set search_path=public as $$
declare part text; matched text[]; breed_uuid uuid; total numeric:=0; seen uuid[]:='{}'; amount numeric;
begin
 delete from sheep_breed_compositions where sheep_id=new.id;
 foreach part in array string_to_array(new.breed,',') loop
 matched:=regexp_match(trim(part),'^(.+?)\s+([0-9]+(?:\.[0-9]+)?)%$');
 if matched is null then raise exception 'Format komposisi ras: Garut 60%%, Texel 40%%';end if;
 select id into breed_uuid from breeds where lower(name)=lower(trim(matched[1]));
 if breed_uuid is null then raise exception 'Ras % belum terdaftar. Tambahkan melalui pengelola database.',matched[1];end if;
 if breed_uuid=any(seen) then raise exception 'Ras tidak boleh duplikat';end if;
 seen:=array_append(seen,breed_uuid);amount:=matched[2]::numeric;total:=total+amount;
 insert into sheep_breed_compositions(sheep_id,owner_id,breed_id,percentage) values(new.id,new.owner_id,breed_uuid,amount);
 end loop;
 if abs(total-100)>0.001 then raise exception 'Total komposisi ras harus 100%%';end if;
 return new;
end; $$;
create trigger sheep_breed_sync after insert or update of breed on sheep for each row execute function sync_breed_compositions();
create unique index one_device_sensor_kind on sensors(device_id,kind);
create function public.sync_device_assignment() returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='INSERT' then
 insert into sensors(owner_id,device_id,kind,unit) values(new.owner_id,new.id,'weight','kg');
 elsif new.sheep_id is not distinct from old.sheep_id then return new;
 end if;
 update device_assignments set ended_at=clock_timestamp() where device_id=new.id and ended_at is null;
 if new.sheep_id is not null then insert into device_assignments(owner_id,device_id,sheep_id) values(new.owner_id,new.id,new.sheep_id);end if;
 return new;
end; $$;
create trigger device_assignment_sync after insert or update of sheep_id on devices for each row execute function sync_device_assignment();
create function public.reading_source_guard() returns trigger language plpgsql set search_path=public as $$
begin
 if auth.uid() is not null and not new.is_simulated then raise exception 'Data perangkat fisik hanya dapat dikirim melalui backend ingestion';end if;
 if new.sensor_id is null then select id into new.sensor_id from sensors where device_id=new.device_id and owner_id=new.owner_id and unit=new.unit limit 1;end if;
 return new;
end; $$;
create trigger reading_guard before insert or update on sensor_readings for each row execute function reading_source_guard();
commit;
