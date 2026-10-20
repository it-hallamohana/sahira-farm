import { useEffect, useRef, useState } from 'react';
import { getContent } from '../lib';
import { initialContent, type PageContent, type Section } from '../content';
import '../public.css';

type Globals = Record<string, string>;
function Arrow({ back = false, down = false }: { back?: boolean; down?: boolean }) {
  return <svg viewBox="0 0 24 24" fill="none" aria-hidden="true" style={{ transform: back ? 'rotate(180deg)' : down ? 'rotate(90deg)' : undefined }}><path d="M4 12h15m-6-6 6 6-6 6" stroke="currentColor" strokeWidth="1.5" /></svg>;
}
function Mark() {
  return <svg viewBox="0 0 48 48" fill="none" aria-hidden="true"><path d="M17 16c-9-12-19 7-7 11 5 2 8-3 5-6m16-5c9-12 19 7 7 11-5 2-8-3-5-6M15 15l4 20 5 5 5-5 4-20c-6-6-12-6-18 0Z" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/><path d="m18 25 3 1m6 0 3-1m-9 9h6" stroke="currentColor" strokeWidth="1.5"/></svg>;
}
function Photo({ src, alt, eager = false }: { src: string; alt: string; eager?: boolean }) {
  return <img src={src || '/images/sheep-pasture.jpg'} alt={alt} loading={eager ? 'eager' : 'lazy'} fetchPriority={eager ? 'high' : 'auto'} onError={event => { const img = event.currentTarget; if (!img.src.endsWith('/images/sheep-pasture.jpg')) img.src = '/images/sheep-pasture.jpg'; }} />;
}
function anchor(value: string | undefined, fallback: string) {
  return value && /^#[\p{L}\p{N}_-]+$/u.test(value) ? value : fallback;
}
function SectionLink({ s, fallback = '#pilihan' }: { s: Section; fallback?: string }) {
  return s.button ? <a className="sf-text-link" href={anchor(s.url, fallback)}>{s.button}<Arrow /></a> : null;
}
function Hero({ s, g }: { s: Section; g: Globals }) {
  return <section id={s.id} className="sf-hero">
    <div className="sf-hero-photo"><Photo src={s.image} alt={g.heroImageAlt} eager /></div>
    <div className="sf-hero-top sf-wrap"><p className="sf-kicker">{s.label}</p><p>{g.heroNote}</p></div>
    <div className="sf-hero-bottom sf-wrap">
      <div className="sf-hero-intro"><p>{s.text}</p><a className="sf-round-link" href={anchor(s.url, '#pilihan')}><span>{s.button}</span><span className="sf-circle"><Arrow down /></span></a></div>
      <h1>{s.title}</h1>
      <div className="sf-hero-caption"><span>{g.heroCaption}</span><a href={anchor(g.secondaryUrl, '#cerita')}>{g.secondaryButton}<Arrow down /></a></div>
    </div>
  </section>;
}
function Story({ s, g }: { s: Section; g: Globals }) {
  return <section id={s.id} className="sf-story sf-wrap">
    <div className="sf-story-heading"><p className="sf-kicker">{s.label}</p><h2>{s.title}</h2></div>
    <div className="sf-story-grid">
      <figure className="sf-story-photo"><Photo src={s.image} alt={g.storyImageAlt} /><figcaption>{g.pastureCaption}<span>SF / 01</span></figcaption></figure>
      <div className="sf-story-copy"><p className="sf-paragraph">{s.text}</p><SectionLink s={s}/><div className="sf-principles">{s.items.map((item, index) => <article key={index}><span>0{index + 1}</span><div><h3>{item.title}</h3><p>{item.text}</p></div></article>)}</div></div>
    </div>
    <div className="sf-story-note"><Mark /><p>{g.pastureNote}</p></div>
  </section>;
}
function Collection({ s, g }: { s: Section; g: Globals }) {
  const [selected, setSelected] = useState(0);
  const track = useRef<HTMLDivElement>(null);
  const active = Math.min(selected, Math.max(0, s.items.length - 1));
  function go(index: number) {
    const el = track.current;
    const next = (index + s.items.length) % s.items.length;
    if (!el || !s.items.length) return;
    const slide = el.children[next] as HTMLElement;
    el.scrollTo({ left: slide.offsetLeft - el.offsetLeft - parseFloat(getComputedStyle(el).paddingLeft), behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' });
    setSelected(next);
  }
  return <section id={s.id} className="sf-collection">
    <div className="sf-wrap sf-collection-heading"><div><p className="sf-kicker">{s.label}</p><h2>{s.title}</h2></div><div><p>{s.text}</p><div className="sf-slider-controls"><span aria-live="polite">{s.items.length ? String(active + 1).padStart(2, '0') : '00'} <span>/ {String(s.items.length).padStart(2, '0')}</span></span><button aria-label="Domba sebelumnya" onClick={() => go(active - 1)} disabled={s.items.length < 2}><Arrow back /></button><button aria-label="Domba berikutnya" onClick={() => go(active + 1)} disabled={s.items.length < 2}><Arrow /></button></div></div></div>
    <div className="sf-slider" ref={track} role="region" aria-roledescription="carousel" aria-label="Jenis domba unggulan" tabIndex={0}
      onKeyDown={e => { if (e.target !== e.currentTarget) return; if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); go(active + (e.key === 'ArrowRight' ? 1 : -1)); } }}
      onScroll={() => { const el = track.current; if (!el) return; let index = 0, distance = Infinity; const padding = parseFloat(getComputedStyle(el).paddingLeft); Array.from(el.children).forEach((child, i) => { const d = Math.abs((child as HTMLElement).offsetLeft - el.offsetLeft - el.scrollLeft - padding); if (d < distance) { index = i; distance = d; } }); setSelected(index); }}>
      {s.items.map((item, index) => <article className="sf-slide" key={index} role="group" aria-roledescription="slide" aria-label={`${index + 1} dari ${s.items.length}: ${item.title}`}>
        <div className="sf-slide-photo"><Photo src={item.image || s.image} alt={`${item.title} — ${g.collectionImageAlt}`} /><span className="sf-slide-index">0{index + 1}</span></div>
        <div className="sf-slide-copy"><span className="sf-kicker">{g.collectionDetailLabel}</span><h3>{item.title}</h3><p>{item.text}</p><SectionLink s={{ ...s, button: g.collectionDetailButton || s.button }} fallback="#kontak" /><span className="sf-slide-signature" aria-hidden="true">{g.siteName}</span></div>
      </article>)}
    </div>
    <div className="sf-wrap sf-collection-bottom"><div className="sf-slide-selectors" aria-label="Pilih jenis domba">{s.items.map((item, i) => <button key={i} aria-current={i === active ? 'true' : undefined} onClick={() => go(i)}>{item.title}</button>)}</div><p>{g.collectionNote}</p></div>
  </section>;
}
function Extra({ s }: { s: Section }) {
  return <section id={s.id} className="sf-extra sf-wrap"><p className="sf-kicker">{s.label}</p><h2>{s.title}</h2><p className="sf-paragraph">{s.text}</p>{s.items.map((item, i) => <details key={i}><summary>{item.title}</summary><p>{item.text}</p></details>)}<SectionLink s={s} fallback="#kontak" /></section>;
}
function Contact({ s, g }: { s: Section; g: Globals }) {
  const hasContact = g.contactPhone || g.contactEmail || g.contactLocation;
  return <section id={s.id} className="sf-contact"><div className="sf-wrap"><p className="sf-kicker">{s.label}</p><div className="sf-contact-grid"><h2>{s.title}</h2><div><p>{s.text}</p>{hasContact ? <dl>{g.contactPhone && <div><dt>{g.contactPhoneLabel}</dt><dd>{g.contactPhone}</dd></div>}{g.contactEmail && <div><dt>{g.contactEmailLabel}</dt><dd>{g.contactEmail}</dd></div>}{g.contactLocation && <div><dt>{g.contactLocationLabel}</dt><dd>{g.contactLocation}</dd></div>}</dl> : <p className="sf-contact-pending">{g.contactUnavailable}</p>}<SectionLink s={s}/></div></div></div></section>;
}
export default function PublicSite({ preview: previewProp }: { preview?: boolean }) {
  const [content, setContent] = useState<PageContent | null>(null);
  const [error, setError] = useState(false), [menu, setMenu] = useState(false), [retry, setRetry] = useState(0);
  const preview = previewProp ?? new URLSearchParams(window.location.search).get('preview') === '1';
  const g = { ...initialContent.globals, ...content?.globals };
  const visible = content?.sections.filter(s => s.visible) || [];
  const byKind = (kind: string) => visible.find(s => s.kind === kind);
  const nav = [{ s: byKind('ecosystem'), label: g.navStory }, { s: byKind('breeds'), label: g.navCollection }, { s: byKind('ml'), label: g.navApproach }, { s: byKind('cta'), label: g.navContact }].filter(x => x.s);
  const home = byKind('hero') ? `#${byKind('hero')!.id}` : '#company-story';
  useEffect(() => { let current = true; setError(false); getContent(preview).then(value => { if (current) setContent(value); }).catch(() => { if (current) setError(true); }); return () => { current = false; }; }, [preview, retry]);
  useEffect(() => { if (!content) return; document.title = content.seoTitle; const meta = document.querySelector('meta[name="description"]'); meta?.setAttribute('content', content.seoDescription); }, [content]);
  useEffect(() => { const close = (e: KeyboardEvent) => { if (e.key === 'Escape') setMenu(false); }; window.addEventListener('keydown', close); return () => window.removeEventListener('keydown', close); }, []);
  return <div className={`public-site ${visible[0]?.kind === 'hero' && !error ? 'sf-has-hero' : ''}`}>
    <a className="sf-skip" href="#company-story">{g.skipLink}</a>
    <header className="sf-header"><div className="sf-wrap"><a className="sf-brand" href={home} aria-label={g.siteName}><Mark /><span>{g.siteName}<small>{g.tagline}</small></span></a><button className="sf-menu" aria-expanded={menu} aria-controls="company-navigation" aria-label={menu ? g.menuClose : g.menuOpen} onClick={() => setMenu(!menu)}>{menu ? 'Tutup' : 'Menu'}<span>{menu ? '−' : '+'}</span></button><nav id="company-navigation" className={menu ? 'is-open' : ''} aria-label="Navigasi utama">{nav.map(({ s, label }) => <a key={s!.id} href={`#${s!.id}`} onClick={() => setMenu(false)}>{label}</a>)}</nav></div></header>
    {preview && <div className="sf-preview">{g.previewLabel} <a href="/admin/konten">Kembali ke editor</a></div>}
    <main id="company-story">{error ? <div className="sf-state sf-wrap" role="alert"><h1>{g.errorTitle}</h1><p>{g.errorText}</p><button className="sf-text-link" onClick={() => setRetry(x => x + 1)}>{g.retryLabel}<Arrow /></button></div> : !content ? <div className="sf-state sf-wrap" role="status">{g.loadingLabel}</div> : visible.length ? visible.map(s => s.kind === 'hero' ? <Hero key={s.id} s={s} g={g}/> : s.kind === 'ecosystem' ? <Story key={s.id} s={s} g={g}/> : s.kind === 'breeds' ? <Collection key={s.id} s={s} g={g}/> : s.kind === 'cta' ? <Contact key={s.id} s={s} g={g}/> : <Extra key={s.id} s={s}/>) : <div className="sf-state sf-wrap"><h1>{g.emptyTitle}</h1></div>}</main>
    <footer className="sf-footer"><div className="sf-wrap"><div className="sf-footer-main"><a href={home} className="sf-brand"><Mark/><span>{g.siteName}<small>{g.footerText}</small></span></a><a className="sf-text-link" href={home}>{g.footerTop}<Arrow down/></a></div><div className="sf-footer-meta"><span>© {new Date().getFullYear()} {g.siteName}</span><a href="/image-credits.html">{g.footerNote} · Kredit fotografi</a><span>INDONESIA</span></div></div></footer>
  </div>;
}
