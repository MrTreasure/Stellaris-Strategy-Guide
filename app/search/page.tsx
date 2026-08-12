import { getAllGuides } from '@/lib/guides';
import { SearchClient } from '@/components/SearchClient';

export default function SearchPage() { const guides = getAllGuides(); return <main className="mx-auto max-w-7xl px-5 py-14"><p className="text-xs tracking-[.22em] text-[#4fd1c5]">ARCHIVE RETRIEVAL SYSTEM</p><h1 className="display mt-3 text-4xl text-[#f0d49a]">检索银河档案</h1><p className="mt-4 max-w-xl text-slate-400">全文检索在浏览器本地完成，支持多关键词交集筛选。</p><div className="mt-9"><SearchClient guides={guides} /></div></main>; }
