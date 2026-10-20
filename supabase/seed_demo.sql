-- Jalankan melalui SQL Editor setelah mengganti UUID_PENGGUNA dengan ID dari Authentication > Users.
-- Seed ini sengaja tidak membuat akun, kata sandi, atau role admin.
do $$
declare demo_owner uuid := 'UUID_PENGGUNA'; a uuid; b uuid;
begin
 if not exists(select 1 from auth.users where id=demo_owner) then raise exception 'Pengguna tidak ditemukan';end if;
 insert into public.sheep(owner_id,name,ear_tag,birth_date,sex,breed,health,barn,photo)
 values(demo_owner,'Aruna','DEMO-JT-023','2026-02-12','betina','Garut 60%, Texel 40%','Sehat','Kandang A','/images/sheep-portrait.webp')
 on conflict(owner_id,ear_tag) do update set name=excluded.name returning id into a;
 insert into public.sheep(owner_id,name,ear_tag,birth_date,sex,breed,health,barn,photo)
 values(demo_owner,'Banyu','DEMO-JT-024','2026-03-10','jantan','Merino 100%','Sehat','Kandang B','/images/sheep-pasture.webp')
 on conflict(owner_id,ear_tag) do update set name=excluded.name returning id into b;
 insert into public.growth_records(owner_id,sheep_id,date,weight,height,notes) values
 (demo_owner,a,'2026-07-12',28.2,61,'Data demonstrasi'),(demo_owner,a,'2026-08-12',32.5,65,'Data demonstrasi'),
 (demo_owner,a,'2026-09-12',36.8,69,'Data demonstrasi'),(demo_owner,a,'2026-10-12',40.6,72,'Data demonstrasi') on conflict(sheep_id,date) do nothing;
 insert into public.sheep_breed_compositions(owner_id,sheep_id,breed_id,percentage) select demo_owner,a,id,case name when 'Garut' then 60 else 40 end from breeds where name in('Garut','Texel') on conflict do nothing;
 insert into public.sheep_breed_compositions(owner_id,sheep_id,breed_id,percentage) select demo_owner,b,id,100 from breeds where name='Merino' on conflict do nothing;
end $$;
