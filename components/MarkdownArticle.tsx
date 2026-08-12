import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';

function anchorId(children: unknown) {
  return String(children).replace(/[`*_]/g, '').toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]+/g, '-').replace(/^-|-$/g, '');
}

export function MarkdownArticle({ content }: { content: string }) {
  return <ReactMarkdown remarkPlugins={[remarkGfm]} components={{
    h2: ({ children }) => <h2 id={anchorId(children)}>{children}</h2>,
    h3: ({ children }) => <h3 id={anchorId(children)}>{children}</h3>,
  }}>{content.replace(/^#\s+.+$/m, '')}</ReactMarkdown>;
}
