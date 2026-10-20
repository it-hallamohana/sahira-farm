export type Item = { title: string; text: string; image?: string };
export type Section = { id: string; kind: string; visible: boolean; label: string; title: string; text: string; image: string; button: string; url: string; items: Item[] };
export type PageContent = { seoTitle: string; seoDescription: string; globals: Record<string, string>; sections: Section[] };

// Starter editorial copy; public text and photography can be replaced in the CMS.
export const initialContent: PageContent = {
  seoTitle: 'Sahira Farm — Rumah bagi domba pilihan',
  seoDescription: 'Berkenalan dengan Sahira Farm. Cerita peternakan, perhatian dalam pemeliharaan, serta karakter domba Garut, Merino, dan Texel.',
  globals: {
    siteName: 'Sahira Farm', tagline: 'Peternakan domba',
    navStory: 'Tentang kami', navCollection: 'Domba pilihan', navApproach: 'Perawatan', navContact: 'Hubungi kami',
    menuOpen: 'Buka navigasi', menuClose: 'Tutup navigasi', skipLink: 'Langsung ke isi',
    heroNote: 'Dari keseharian yang sederhana, tumbuh kualitas yang istimewa.',
    heroAnnotation: 'Tumbuh dengan baik.', heroCaption: 'DEKAT DENGAN ALAM. DEKAT DENGAN TERNAK.',
    heroImageAlt: 'Domba di antara dedaunan hijau di Cisaloka, Tangerang',
    secondaryButton: 'Kenali Sahira', secondaryUrl: '#cerita',
    pastureNote: 'Merawat hari ini.\nMenumbuhkan esok.', pastureCaption: 'CERITA DARI KANDANG',
    storyImageAlt: 'Domba Garut sedang dirawat di kandang',
    collectionIndex: 'KENALI KARAKTERNYA', collectionNote: 'Kenali rasnya, lalu temukan domba yang sesuai dengan rencana Anda. Ketersediaan ternak dapat ditanyakan langsung kepada kami.',
    collectionDetailLabel: 'DOMBA PILIHAN', collectionDetailButton: 'Tanyakan ketersediaan',
    collectionImageAlt: 'Foto ilustrasi ras domba',
    careImageAlt: 'Domba di peternakan', careCaption: 'TUMBUH DARI PERHATIAN', approachNote: 'Setiap domba punya cerita.',
    contactLabel: 'MULAI PERCAKAPAN', contactPhone: '', contactEmail: '', contactLocation: '',
    contactUnavailable: 'Kanal kontak Sahira Farm akan segera hadir.',
    contactPhoneLabel: 'Telepon', contactEmailLabel: 'Email', contactLocationLabel: 'Lokasi',
    footerText: 'Rumah bagi domba pilihan.', footerNote: 'Foto ilustrasi', footerTop: 'Kembali ke atas',
    previewLabel: 'Pratinjau draft — belum dipublikasikan.',
    loadingLabel: 'Menyiapkan cerita Sahira Farm…', emptyTitle: 'Cerita baru sedang disiapkan.',
    errorTitle: 'Halaman belum dapat dimuat.', errorText: 'Silakan coba kembali.', retryLabel: 'Muat kembali',
  },
  sections: [
    { id: 'beranda', kind: 'hero', visible: true, label: 'PETERNAKAN DOMBA / INDONESIA',
      title: 'Sahira Farm', text: 'Rumah bagi domba pilihan.\nTumbuh baik, dirawat sepenuh hati.',
      image: '/images/sheep-pasture.jpg', button: 'Temui domba kami', url: '#pilihan', items: [] },
    { id: 'cerita', kind: 'ecosystem', visible: true, label: '01 — TENTANG SAHIRA',
      title: 'Berawal dari perhatian.\nTumbuh menjadi kepercayaan.',
      text: 'Di Sahira Farm, beternak adalah tentang hadir setiap hari. Mengenal satu per satu domba, memperhatikan pakannya, dan memberi ruang yang nyaman untuk tumbuh.\n\nKami ingin membawa semangat itu lebih dekat kepada Anda. Mempertemukan kecintaan pada peternakan dengan pemeliharaan yang telaten, agar setiap pilihan punya cerita yang bisa dipercaya.',
      image: '/images/sheep-garut.jpg', button: 'Kenali domba pilihan', url: '#pilihan',
      items: [
        { title: 'Dikenali satu per satu', text: 'Setiap domba memiliki karakter dan kebutuhan yang berbeda. Dari situlah perhatian kami dimulai.' },
        { title: 'Dirawat setiap hari', text: 'Pakan, kebersihan kandang, dan pengamatan kondisi menjadi bagian dari keseharian peternakan.' },
        { title: 'Dipilih bersama Anda', text: 'Kami membuka percakapan tentang tujuan pemeliharaan, karakter ras, dan pilihan yang sesuai.' },
      ] },
    { id: 'pilihan', kind: 'breeds', visible: true, label: '02 — DOMBA PILIHAN',
      title: 'Beda karakter.\nSama istimewanya.',
      text: 'Dari pesona domba lokal hingga karakter ras dunia. Berkenalan dengan tiga pilihan yang mewarnai cerita Sahira Farm.',
      image: '/images/sheep-garut.jpg', button: 'Tanyakan ketersediaan', url: '#kontak',
      items: [
        { title: 'Garut', text: 'Karakter kuat dari tanah Pasundan. Domba Garut dikenal dengan postur yang gagah dan tanduk melingkar pada pejantannya. Warisan peternakan Jawa Barat dengan pesona yang mudah dikenali.', image: '/images/sheep-garut.jpg' },
        { title: 'Merino', text: 'Lembut dalam tampilan, khas dalam karakter. Merino dikenal karena wolnya yang halus dan lebat. Pilihan untuk mengenal sisi lain peternakan domba, dengan perhatian khusus pada kebersihan dan perawatan bulu.', image: '/images/sheep-merino.jpg' },
        { title: 'Texel', text: 'Perawakan padat dengan wajah yang khas. Texel dikenal sebagai ras domba pedaging dengan tubuh berotot dan bulu putih. Karakternya menarik untuk dikenali dalam rencana pengembangan ternak.', image: '/images/sheep-texel.jpg' },
      ] },
    { id: 'kontak', kind: 'cta', visible: true, label: 'ADA RENCANA BAIK?', title: 'Mari bertemu.\nMari bertumbuh.',
      text: 'Mencari domba pilihan, merencanakan peternakan, atau ingin mengenal Sahira lebih dekat? Kami senang mendengar cerita Anda.',
      image: '', button: 'Kembali mengenal domba', url: '#pilihan', items: [] },
  ],
};
