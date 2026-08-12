import type { Metadata } from 'next';
import Link from 'next/link';
import './globals.css';

export const metadata: Metadata = { title: 'Stellaris 银河战略档案', description: 'Stellaris 4.4.6 Pegasus 攻略与存档复盘' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body><header className="border-b border-cyan-200/15 bg-[#070b14]/85 backdrop-blur"><div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4"><Link href="/" className="display text-sm text-[#f0d49a] sm:text-base">STELLARIS // 银河战略档案</Link><nav className="flex items-center gap-5 text-sm text-slate-300"><Link href="/">档案库</Link><Link href="/search">检索</Link><span className="hidden text-xs text-[#4fd1c5] sm:inline">PEGASUS 4.4.6</span></nav></div></header>{children}<footer className="mt-16 border-t border-cyan-200/10 px-5 py-8 text-center text-xs tracking-widest text-slate-500">GALACTIC STRATEGY ARCHIVE · 静态部署 · 内容随仓库构建更新</footer></body></html>;
}
