'use client';
import { useMemo, useState } from 'react';
import { GuideCard } from '@/components/GuideCard';
import type { Guide } from '@/lib/guides';

export function SearchClient({ guides }: { guides: Guide[] }) {
  const [query, setQuery] = useState('');
  const results = useMemo(() => { const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean); return words.length ? guides.filter((guide) => words.every((word) => `${guide.title} ${guide.excerpt} ${guide.content}`.toLowerCase().includes(word))) : guides; }, [guides, query]);
  return <><label className="archive-frame flex items-center bg-[#0b1321] px-4"><span className="mr-3 text-[#4fd1c5]">⌕</span><input autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="检索起源、传统、飞升、资源或存档问题..." className="w-full bg-transparent py-4 text-slate-100 outline-none placeholder:text-slate-600" /></label><p className="my-6 text-sm text-slate-500">{query ? `检索到 ${results.length} 份匹配档案` : `全部 ${results.length} 份档案`}</p><div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">{results.map((guide) => <GuideCard guide={guide} key={guide.slug} />)}</div>{!results.length && <p className="py-16 text-center text-slate-500">未在银河档案中找到匹配记录。</p>}</>;
}
