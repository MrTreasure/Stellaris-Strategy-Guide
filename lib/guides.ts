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
  '00': { difficulty: '基础', dlc: '本体', image: '/images/deep-space.jpg' },
  '01': { difficulty: '中', dlc: '虚境幽影', image: '/images/deep-space.jpg' },
  '02': { difficulty: '中', dlc: '人型包 / 万物竞发', image: '/images/deep-space.jpg' },
  '03': { difficulty: '中高', dlc: '万物竞发', image: '/images/deep-space.jpg' },
  '04': { difficulty: '中高', dlc: '万物竞发', image: '/images/deep-space.jpg' },
  '05': { difficulty: '高', dlc: '游牧', image: '/images/voidfarer-arkship.jpg' },
  '06': { difficulty: '中', dlc: '虚境幽影', image: '/images/deep-space.jpg' },
  '07': { difficulty: '中高', dlc: '万物竞发', image: '/images/deep-space.jpg' },
  '08': { difficulty: '中高', dlc: '毒物种包', image: '/images/deep-space.jpg' },
  '09': { difficulty: '中', dlc: '机械纪元', image: '/images/deep-space.jpg' },
  '10': { difficulty: '高', dlc: '机械纪元', image: '/images/deep-space.jpg' },
  '11': { difficulty: '中', dlc: '机械纪元', image: '/images/deep-space.jpg' },
  '12': { difficulty: '高', dlc: '石质类物种包', image: '/images/deep-space.jpg' },
  '13': { difficulty: '中高', dlc: '霸主 / 死灵物种包', image: '/images/deep-space.jpg' },
  '14': { difficulty: '中', dlc: '合成人黎明 / 星界位面', image: '/images/deep-space.jpg' },
  '15': { difficulty: '中', dlc: '植物类物种包', image: '/images/deep-space.jpg' },
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
  const slug = `${kind === '开局攻略' ? 'guide' : 'review'}-${filename.replace(/\.md$/, '')}`;
  return {
    slug,
    title,
    excerpt: paragraph.slice(0, 165) + (paragraph.length > 165 ? '...' : ''),
    content,
    kind,
    difficulty: meta?.difficulty ?? '复盘',
    dlc: meta?.dlc ?? '实战存档',
    image: meta?.image ?? '/images/deep-space.jpg',
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
