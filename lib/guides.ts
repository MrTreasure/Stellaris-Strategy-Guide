import fs from 'node:fs';
import path from 'node:path';

export type GuideKind = '开局攻略' | '存档复盘';

export type Guide = {
  slug: string;
  title: string;
  excerpt: string;
  content: string;
  kind: GuideKind;
  difficulty: string;
  dlc: string;
  image: string;
  headings: { id: string; text: string; level: number }[];
};

const contentRoot = path.join(process.cwd(), 'content');

const metadata: Record<string, Pick<Guide, 'difficulty' | 'dlc' | 'image'>> = {
  '00': { difficulty: '基础', dlc: '本体', image: '/images/guide-00.jpg' },
  '01': { difficulty: '中', dlc: '虚境幽影', image: '/images/guide-01.jpg' },
  '02': { difficulty: '中', dlc: '人型包 / 万物竞发', image: '/images/guide-02.jpg' },
  '03': { difficulty: '中高', dlc: '万物竞发', image: '/images/guide-03.jpg' },
  '04': { difficulty: '中高', dlc: '万物竞发', image: '/images/guide-04.jpg' },
  '05': { difficulty: '高', dlc: '游牧', image: '/images/guide-05.jpg' },
  '06': { difficulty: '中', dlc: '虚境幽影', image: '/images/guide-06.jpg' },
  '07': { difficulty: '中高', dlc: '万物竞发', image: '/images/guide-07.jpg' },
  '08': { difficulty: '中高', dlc: '毒物种包', image: '/images/guide-08.jpg' },
  '09': { difficulty: '中', dlc: '机械纪元', image: '/images/guide-09.jpg' },
  '10': { difficulty: '高', dlc: '机械纪元', image: '/images/guide-10.jpg' },
  '11': { difficulty: '中', dlc: '机械纪元', image: '/images/guide-11.jpg' },
  '12': { difficulty: '高', dlc: '石质类物种包', image: '/images/guide-12.jpg' },
  '13': { difficulty: '中高', dlc: '霸主 / 死灵物种包', image: '/images/guide-13.jpg' },
  '14': { difficulty: '中', dlc: '合成人黎明 / 星界位面', image: '/images/guide-14.jpg' },
  '15': { difficulty: '中', dlc: '植物类物种包', image: '/images/guide-15.jpg' },
  '16': { difficulty: '中', dlc: '乌托邦', image: '/images/guide-16.jpg' },
};

const reviewImages: Record<string, string> = {
  '存档复盘_人类联邦_实验审判_2340.md': '/images/review-01.jpg',
  '存档复盘_人类联邦_实验审判_2384.md': '/images/review-02.jpg',
  '存档复盘_终焉骑士团_2260.md': '/images/review-03.jpg',
  '存档复盘_终焉骑士团_2264.md': '/images/review-04.jpg',
};

const reviewSlugs: Record<string, string> = {
  '存档复盘_人类联邦_实验审判_2340.md': 'review-01',
  '存档复盘_人类联邦_实验审判_2384.md': 'review-02',
  '存档复盘_终焉骑士团_2260.md': 'review-03',
  '存档复盘_终焉骑士团_2264.md': 'review-04',
};

function slugify(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]+/g, '-').replace(/^-|-$/g, '');
}

function fileToGuide(kind: GuideKind, filename: string): Guide {
  const content = fs.readFileSync(path.join(contentRoot, kind, filename), 'utf8');
  const title = content.match(/^#\s+(.+)$/m)?.[1].trim() ?? filename.replace(/\.md$/, '');
  const paragraph = content
    .split('\n')
    .map((line) => line.replace(/^>\s*/, '').trim())
    .find((line) => line.length > 35 && !line.startsWith('#') && !line.startsWith('|')) ?? '';
  const headings = [...content.matchAll(/^(#{2,3})\s+(.+)$/gm)].map((match) => ({
    id: slugify(match[2].replace(/[`*_]/g, '')),
    text: match[2].replace(/[`*_]/g, ''),
    level: match[1].length,
  }));
  const code = filename.match(/^(\d{2})/)?.[1];
  const meta = code ? metadata[code] : undefined;
  // Keep export route names ASCII-only. Next 16 can hydrate a static HTML page
  // with a decoded Unicode pathname, then fail to match its encoded RSC payload.
  const slug = kind === '开局攻略' ? `guide-${code}` : reviewSlugs[filename];
  if (!slug) throw new Error(`Missing static slug for ${filename}`);
  return {
    slug,
    title,
    excerpt: paragraph.slice(0, 165) + (paragraph.length > 165 ? '...' : ''),
    content,
    kind,
    difficulty: meta?.difficulty ?? '复盘',
    dlc: meta?.dlc ?? '实战存档',
    image: meta?.image ?? reviewImages[filename] ?? '/images/deep-space.jpg',
    headings,
  };
}

export function getAllGuides(): Guide[] {
  return (['开局攻略', '存档复盘'] as GuideKind[]).flatMap((kind) =>
    fs.readdirSync(path.join(contentRoot, kind)).filter((file) => file.endsWith('.md')).sort().map((file) => fileToGuide(kind, file)),
  );
}

export function getGuide(slug: string) {
  return getAllGuides().find((guide) => guide.slug === slug);
}
