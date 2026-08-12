import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { MarkdownArticle } from '@/components/MarkdownArticle';
import { getAllGuides, getGuide } from '@/lib/guides';

export function generateStaticParams() { return getAllGuides().map(({ slug }) => ({ slug })); }
export function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> { return params.then(({ slug }) => { const guide = getGuide(slug); return { title: guide ? `${guide.title} | 银河战略档案` : '档案未找到' }; }); }

export default async function GuidePage({ params }: { params: Promise<{ slug: string }> }) {
  const guide = getGuide((await params).slug); if (!guide) notFound();
  return <main className="mx-auto max-w-7xl px-5 py-10"><div className="archive-frame corner overflow-hidden bg-[#0a1220]/90"><div className="relative min-h-64 bg-cover bg-center p-7 sm:p-12" style={{ backgroundImage: `linear-gradient(90deg, rgba(6,10,19,.93), rgba(6,10,19,.5)), url('${guide.image}')` }}><p className="text-xs tracking-[.22em] text-[#4fd1c5]">{guide.kind === '开局攻略' ? 'STARTING BLUEPRINT' : 'AFTER ACTION REPORT'}</p><h1 className="display mt-5 max-w-4xl text-3xl leading-tight text-[#f1d9a8] sm:text-5xl">{guide.title}</h1><div className="mt-6 flex gap-2 text-xs"><span className="border border-[#c9a86a]/50 px-2 py-1 text-[#f0d49a]">难度：{guide.difficulty}</span><span className="border border-[#4fd1c5]/40 px-2 py-1 text-[#7ae0da]">{guide.dlc}</span></div></div></div><div className="mt-8 grid gap-10 lg:grid-cols-[minmax(0,1fr)_250px]"><article className="prose-guide min-w-0"><MarkdownArticle content={guide.content} /></article><aside className="order-first lg:order-last"><div className="sticky top-6 border-l border-[#c9a86a]/40 pl-5"><p className="mb-4 text-xs tracking-[.2em] text-[#c9a86a]">本篇目录</p><nav className="space-y-2 text-sm">{guide.headings.map((heading) => <a key={heading.id} className={`block leading-5 text-slate-400 hover:text-[#4fd1c5] ${heading.level === 3 ? 'ml-3 text-xs' : ''}`} href={`#${heading.id}`}>{heading.text}</a>)}</nav></div></aside></div></main>;
}
