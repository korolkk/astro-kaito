import { getCollection } from 'astro:content';

export async function GET() {
	const posts = await getCollection('blog');
	const index = posts.map((post) => ({
		title: post.data.title,
		description: post.data.description,
		url: `/blog/${post.id}/`,
		date: post.data.pubDate,
		tags: post.data.tags || [],
	}));
	return new Response(JSON.stringify(index), {
		headers: { 'Content-Type': 'application/json' },
	});
}
