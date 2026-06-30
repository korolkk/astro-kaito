import { getCollection } from 'astro:content';

function stripMarkdown(md) {
	if (!md) return '';
	let text = md;
	// Remove frontmatter
	text = text.replace(/^---[\s\S]*?---\n?/, '');
	// Remove code blocks
	text = text.replace(/```[\s\S]*?```/g, ' ');
	// Remove inline code
	text = text.replace(/`[^`]+`/g, ' ');
	// Remove images
	text = text.replace(/!\[.*?\]\(.*?\)/g, ' ');
	// Remove links, keep text
	text = text.replace(/\[([^\]]*)\]\(.*?\)/g, '$1');
	// Remove HTML tags
	text = text.replace(/<[^>]+>/g, ' ');
	// Remove headings markers
	text = text.replace(/^#{1,6}\s+/gm, '');
	// Remove bold/italic markers
	text = text.replace(/[*_]{1,3}/g, '');
	// Remove blockquotes
	text = text.replace(/^>\s?/gm, '');
	// Remove horizontal rules
	text = text.replace(/^[-*_]{3,}\s*$/gm, '');
	// Remove list markers
	text = text.replace(/^[\s]*[-*+]\s/gm, '');
	text = text.replace(/^[\s]*\d+\.\s/gm, '');
	// Collapse whitespace
	text = text.replace(/\s+/g, ' ').trim();
	return text;
}

export async function GET() {
	const posts = await getCollection('blog');
	const index = posts.map((post) => ({
		title: post.data.title,
		description: post.data.description,
		url: `/blog/${post.id}/`,
		date: post.data.pubDate,
		tags: post.data.tags || [],
		body: stripMarkdown(post.body || '').substring(0, 2000),
	}));
	return new Response(JSON.stringify(index), {
		headers: { 'Content-Type': 'application/json' },
	});
}
