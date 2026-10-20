import React, { lazy, Suspense, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Routes, Route, Link, NavLink, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { ArrowLeft, ArrowUpRight, LayoutDashboard, Radio, NotebookPen, LogOut, Leaf, Menu, X } from 'lucide-react';
import { demo, localPreview, supabase } from './lib';
import './style.css';
import './admin.css';
const PublicSite = lazy(() => import('./pages/PublicSite'));
const Dashboard = lazy(() => import('./pages/Dashboard').then(m => ({ default: m.Dashboard })));
const Admin = lazy(() => import('./pages/ContentEditor'));
const RFID = lazy(() => import('./pages/RFID'));

function Wordmark() { return <Link className="brand" to="/"><Leaf size={29} strokeWidth={1.2}/><span>SAHIRA FARM<small>THE FARM OFFICE</small></span></Link>; }

function Login() {
  const [email,setEmail] = useState(''), [password,setPassword] = useState(''), [mode,setMode] = useState<'login'|'activate'>('login');
  const [message,setMessage] = useState(''), [busy,setBusy] = useState(false);
  const navigate = useNavigate();
  async function submit(event: React.FormEvent) {
    event.preventDefault(); if (!supabase) return;
    setBusy(true); setMessage('');
    try {
      if (mode === 'activate') {
        const {error} = await supabase.auth.signUp({email:email.trim(),password,options:{emailRedirectTo:location.origin+'/admin/akses'}});
        if(error) throw error;
        setMessage('Periksa email untuk mengonfirmasi akun. Setelah konfirmasi, kembali ke halaman ini dan gunakan email serta kata sandi Anda. Hanya email yang ditetapkan pengelola mendapat akses admin.');
      } else {
        const {error} = await supabase.auth.signInWithPassword({email:email.trim(),password});
        if(error) throw error;
        navigate('/admin');
      }
    } catch(error) { setMessage(error instanceof Error?error.message:'Permintaan belum berhasil. Coba lagi.'); }
    finally {setBusy(false);}
  }
  return <main className="office-access"><section className="access-photo"><img src="/images/goat-herd.jpg" alt="Fotografi ilustrasi kawanan kambing di padang rumput"/><div><span>SAHIRA FARM</span><h1>Setiap ternak,<br/><em>punya catatan.</em></h1><p>Ruang kerja untuk merawat, memahami,<br/>dan mengembangkan peternakan.</p></div></section><section className="access-form"><Link className="back-link" to="/"><ArrowLeft size={16}/>Kembali ke Sahira Farm</Link><div><p className="eyebrow">RUANG PENGELOLA</p><h2>{mode==='login'?'Selamat datang.':'Aktifkan akun Anda.'}</h2><p className="muted">{mode==='login'?'Lanjutkan catatan peternakan hari ini.':'Gunakan email admin yang telah didaftarkan oleh pengelola.'}</p>{demo?<p className="notice">Koneksi database belum tersedia. Periksa konfigurasi aplikasi.</p>:<form onSubmit={submit}><label>Email<input name="email" type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)}/></label><label>Kata sandi<input name="password" type="password" autoComplete={mode==='activate'?'new-password':'current-password'} minLength={mode==='activate'?10:1} required value={password} onChange={e=>setPassword(e.target.value)}/></label><button disabled={busy} className="button">{busy?'Memproses…':mode==='activate'?'Buat akun':'Buka ruang pengelola'}<ArrowUpRight size={16}/></button></form>}<p role="status" className="auth-message">{message}</p><button className="text-link" onClick={()=>{setMode(mode==='login'?'activate':'login');setMessage('');}}>{mode==='login'?'Pertama kali? Aktifkan akun':'Sudah memiliki akun? Kembali'}</button></div><small>SAHIRA FARM / PRIVATE WORKSPACE</small></section></main>;
}

function Guard({children}:{children:React.ReactNode}) {
  const [state,setState] = useState<'loading'|'allowed'|'login'|'denied'>('loading');
  const [error,setError] = useState('');
  useEffect(()=> {
    let alive = true;
    async function verify() {
      if(!supabase){if(alive)setState(localPreview?'allowed':'denied');return;}
      try {
        const {data,error:userError}=await supabase.auth.getUser();
        if(userError||!data.user){if(alive)setState('login');return;}
        let role = await supabase.from('user_roles').select('role').eq('user_id',data.user.id).eq('role','admin').maybeSingle();
        if(!role.data){await supabase.rpc('claim_farm_admin');role=await supabase.from('user_roles').select('role').eq('user_id',data.user.id).eq('role','admin').maybeSingle();}
        if(role.error)throw role.error;
        if(alive)setState(role.data?'allowed':'denied');
      }catch(e){if(alive){setError(e instanceof Error?e.message:'Akses belum dapat diperiksa.');setState('denied');}}
    }
    verify();
    const subscription=supabase?.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'&&alive)setState('login');});
    return ()=>{alive=false;subscription?.data.subscription.unsubscribe();};
  },[]);
  if(state==='loading')return <div className="office-loading">Menyiapkan ruang kerja…</div>;
  if(state==='login')return <Navigate to="/admin/akses" replace/>;
  if(state==='denied')return <main className="access-denied"><p className="eyebrow">SAHIRA FARM</p><h1>Akses belum tersedia.</h1><p>{error||'Email akun ini belum memiliki peran pengelola. Pastikan email telah dikonfirmasi dan sesuai dengan akun admin yang didaftarkan.'}</p><div className="actions"><button className="button" onClick={async()=>{await supabase?.auth.signOut();location.assign('/admin/akses');}}>Gunakan akun lain</button><Link className="text-link" to="/">Kembali ke website</Link></div></main>;
  return <>{children}</>;
}

function AppShell({children,title}:{children:React.ReactNode;title:string}) {
  const navigate=useNavigate(),[menu,setMenu]=useState(false);
  return <div className="app-shell sahira-office"><aside className={menu?'office-sidebar open':'office-sidebar'}><Wordmark/><button className="office-menu" onClick={()=>setMenu(!menu)} aria-label="Buka navigasi pengelola">{menu?<X/>:<Menu/>}</button><span className="eyebrow">CATATAN PETERNAKAN</span><NavLink to="/admin" end onClick={()=>setMenu(false)}><LayoutDashboard size={18}/>Kambing & pertumbuhan</NavLink><NavLink to="/admin/rfid" onClick={()=>setMenu(false)}><Radio size={18}/>RFID & perangkat</NavLink><NavLink to="/admin/konten" onClick={()=>setMenu(false)}><NotebookPen size={18}/>Website & konten</NavLink><Link to="/" target="_blank">Lihat company profile<ArrowUpRight size={16}/></Link><div className="sidebar-note">Satu identitas.<br/>Riwayat yang terus tumbuh.</div><button onClick={async()=>{await supabase?.auth.signOut();navigate('/admin/akses');}}><LogOut size={17}/>Keluar</button></aside><main className="app-main">{localPreview&&<div className="notice">Pratinjau lokal - Data demonstrasi terpisah dari database Sahira Farm.</div>}<div className="app-top"><span>SAHIRA FARM / {title}</span><span className="office-connection">{supabase?'Database terkonfigurasi':'Konfigurasi diperlukan'}</span></div>{children}</main></div>;
}
function PublicRoute(){const location=useLocation();return new URLSearchParams(location.search).get('preview')==='1'?<Guard><PublicSite/></Guard>:<PublicSite/>;}
function LegacyDashboard(){const location=useLocation();return <Navigate to={'/admin'+location.search} replace/>;}
function Office({children,title}:{children:React.ReactNode;title:string}){return <Guard><AppShell title={title}>{children}</AppShell></Guard>;}
createRoot(document.getElementById('root')!).render(<BrowserRouter><Suspense fallback={<div className="office-loading">Menyiapkan halaman…</div>}><Routes><Route path="/" element={<PublicRoute/>}/><Route path="/admin/akses" element={<Login/>}/><Route path="/admin" element={<Office title="MONITORING"><Dashboard/></Office>}/><Route path="/admin/konten" element={<Office title="EDITORIAL"><Admin/></Office>}/><Route path="/admin/rfid" element={<Office title="RFID & PERANGKAT"><RFID/></Office>}/><Route path="/login" element={<Navigate to="/admin/akses" replace/>}/><Route path="/dashboard" element={<LegacyDashboard/>}/><Route path="*" element={<div className="access-denied"><h1>Halaman belum ditemukan.</h1><Link to="/">Kembali ke Sahira Farm</Link></div>}/></Routes></Suspense></BrowserRouter>);
