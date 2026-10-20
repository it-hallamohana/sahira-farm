import {describe,it,expect,vi,beforeEach} from 'vitest';
import {adg,safeUrl,parseBreedComposition,getContent,saveContent} from './lib';
import {initialContent} from './content';
vi.mock('@supabase/supabase-js',()=>({createClient:()=>null}));
describe('Average Daily Gain',()=>{
 it('mengurutkan tanggal dan mengembalikan gram per hari',()=>expect(adg([{date:'2026-02-11',weight:23},{date:'2026-02-01',weight:20}])).toBe(300));
 it('tidak membagi nol ketika tanggal sama',()=>expect(adg([{date:'2026-02-01',weight:20},{date:'2026-02-01',weight:23}])).toBeNull());
 it('membutuhkan setidaknya dua pengukuran',()=>expect(adg([{date:'2026-02-01',weight:20}])).toBeNull());
 it('mempertahankan penurunan berat',()=>expect(adg([{date:'2026-02-01',weight:23},{date:'2026-02-11',weight:20}])).toBe(-300));
});
describe('URL konten',()=>{it('menolak URL skrip dan URL protocol relative',()=>{expect(safeUrl('javascript:alert(1)')).toBe('/');expect(safeUrl('//evil.test')).toBe('/');expect(safeUrl('/\\evil.test')).toBe('/');expect(safeUrl('/\n/evil.test')).toBe('/');});it('menerima URL web dan route internal',()=>{expect(safeUrl('/dashboard')).toBe('/dashboard');expect(safeUrl('https://example.com')).toBe('https://example.com');});});
describe('Komposisi ras',()=>{it('menerima persilangan dengan total 100%',()=>expect(parseBreedComposition('Garut 60%, Texel 40%')).toEqual([{name:'Garut',percentage:60},{name:'Texel',percentage:40}]));it('menolak total yang salah dan ras duplikat',()=>{expect(parseBreedComposition('Garut 20%, Texel 40%')).toBeNull();expect(parseBreedComposition('Garut 60%, Garut 40%')).toBeNull();});});
describe('Pemisahan konten demo',()=>{beforeEach(()=>{const values=new Map<string,string>();vi.stubGlobal('localStorage',{getItem:(key:string)=>values.get(key)||null,setItem:(key:string,v:string)=>values.set(key,v)});});it('draft tidak mengubah publik sampai publish',async()=>{const draft={...initialContent,seoTitle:'Draft yang berbeda'};await saveContent(draft);expect((await getContent()).seoTitle).toBe(initialContent.seoTitle);expect((await getContent(true)).seoTitle).toBe(draft.seoTitle);await saveContent(draft,true);expect((await getContent()).seoTitle).toBe(draft.seoTitle);});});
