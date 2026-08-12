import type { Guide } from '@/lib/guides';

export function GuideCard({ guide }: { guide: Guide }) {
  // Keep guide cards as document navigations: this static site is served by
  // nginx, and dynamic routes must not be resolved through Next's RSC router.
  return <a href={`/guides/${guide.slug}/`} className="group corner archive-frame block overflow-hidden bg-[#0b1321]/90 transition hover:-translate-y-1 hover:border-[#4fd1c5]/70">
    <div className="h-28 bg-cover bg-center opacity-70 transition duration-500 group-hover:scale-105 group-hover:opacity-100" style={{ backgroundImage: `linear-gradient(90deg, rgba(7,11,20,.25), rgba(7,11,20,.82)), url('${guide.image}')` }} />
    <div className="p-5"><div className="mb-3 flex flex-wrap gap-2 text-[11px]"><span className="border border-[#c9a86a]/50 px-2 py-1 text-[#f0d49a]">{guide.difficulty}</span><span className="border border-[#4fd1c5]/35 px-2 py-1 text-[#79e2db]">{guide.dlc}</span></div><h2 className="display text-lg leading-snug text-slate-100">{guide.title}</h2><p className="mt-3 line-clamp-3 text-sm leading-6 text-slate-400">{guide.excerpt}</p><div className="mt-5 text-xs tracking-widest text-[#4fd1c5]">开启档案 →</div></div>
  </a>;
}
