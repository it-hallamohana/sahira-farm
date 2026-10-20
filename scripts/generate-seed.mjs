import fs from 'node:fs';
import ts from 'typescript';
const source=ts.transpile(fs.readFileSync('src/content.ts','utf8'),{module:ts.ModuleKind.ESNext});
const {initialContent}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const delimiter='$content$';
const sql=`begin;
insert into public.pages(id,slug,title) values('home','/','Beranda') on conflict do nothing;
insert into public.breeds(name,description) values('Garut','Ras lokal Indonesia'),('Merino','Penghasil wol halus'),('Texel','Ras produksi daging') on conflict do nothing;
insert into public.content_versions(page_id,status,content) select 'home','published',${delimiter}${JSON.stringify(initialContent)}${delimiter}::jsonb where not exists(select 1 from public.content_versions where page_id='home' and status='published');
do $$
declare v record; item jsonb; section_uuid uuid; field text; position_no integer;
begin
for v in select id,content from public.content_versions where page_id='home' and status='published' and not exists(select 1 from sections where version_id=content_versions.id) loop
position_no:=0;
for item in select value from jsonb_array_elements(v.content->'sections') loop
insert into public.sections(version_id,section_key,kind,position,visible) values(v.id,item->>'id',item->>'kind',position_no,(item->>'visible')::boolean) returning id into section_uuid;
foreach field in array array['label','title','text','image','button','url','items'] loop insert into public.content_blocks(section_id,block_key,payload) values(section_uuid,field,coalesce(item->field,'null'::jsonb));end loop;
position_no:=position_no+1;
end loop;
end loop;
end $$;
commit;
`;
fs.writeFileSync('supabase/seed.sql',sql);
