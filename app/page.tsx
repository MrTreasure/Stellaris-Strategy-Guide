import Link from 'next/link';
import { GuideCard } from '@/components/GuideCard';
import { getAllGuides } from '@/lib/guides';

export default function Home() {
  const guides = getAllGuides();
  const openings = guides.filter((guide) => guide.kind === '开局攻略');
  const reviews = guides.filter((guide) => guide.kind === '存档复盘');
  return <main><section className="relative overflow-hidden border-b border-[#c9a86a]/30"><div className="mx-auto max-w-7xl px-5 py-20 sm:py-28"><p className="mb-5 text-xs tracking-[.25em] text-[#4fd1c5]">IMPERIAL ARCHIVES / PEGASUS EDITION</p><h1 className="display max-w-3xl text-4xl leading-tight text-[#f2dbac] sm:text-6xl">群星战略<br />银河档案库</h1><p className="mt-7 max-w-2xl text-base leading-8 text-slate-300">16 套 4.4.6 特色开局，覆盖起源发动机、前三球、凝聚力预算、传统与飞升节奏；附 4 份实战存档复盘。</p><div className="mt-9 flex gap-4"><a href="#guides" className="border border-[#c9a86a] bg-[#c9a86a]/10 px-5 py-3 text-sm text-[#f2dbac]">浏览开局攻略</a><Link href="/search" className="border border-[#4fd1c5]/60 px-5 py-3 text-sm text-[#77e4dc]">全文检索</Link></div></div></section><section id="guides" className="mx-auto max-w-7xl px-5 py-14"><div className="mb-8 flex items-end justify-between"><div><p className="text-xs tracking-[.2em] text-[#4fd1c5]">STARTING BLUEPRINTS</p><h2 className="display mt-2 text-3xl text-[#f0d49a]">开局攻略</h2></div><span className="text-sm text-slate-500">{openings.length} 份档案</span></div><div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">{openings.map((guide) => <GuideCard key={guide.slug} guide={guide} />)}</div></section><section className="border-y border-cyan-100/10 bg-[#07101d]/65"><div className="mx-auto max-w-7xl px-5 py-14"><p className="text-xs tracking-[.2em] text-[#4fd1c5]">AFTER ACTION REPORTS</p><h2 className="display mt-2 text-3xl text-[#f0d49a]">存档复盘</h2><div className="mt-8 grid gap-5 md:grid-cols-2 xl:grid-cols-4">{reviews.map((guide) => <GuideCard key={guide.slug} guide={guide} />)}</div></div></section></main>;
}
