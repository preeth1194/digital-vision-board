import type { MetadataRoute } from 'next'
import { CRAWLABLE_PATHS, getSiteUrl } from '@/lib/seo'

const changeFreqByPath: Partial<Record<(typeof CRAWLABLE_PATHS)[number], MetadataRoute.Sitemap[number]['changeFrequency']>> = {
  '/': 'weekly',
  '/contact': 'monthly',
  '/faq': 'monthly',
  '/privacy-policy': 'yearly',
  '/terms': 'yearly',
}

const priorityByPath: Partial<Record<(typeof CRAWLABLE_PATHS)[number], number>> = {
  '/': 1,
  '/contact': 0.6,
  '/faq': 0.6,
  '/privacy-policy': 0.3,
  '/terms': 0.3,
}

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = getSiteUrl()
  const now = new Date()

  return CRAWLABLE_PATHS.map((path) => ({
    url: `${siteUrl}${path}`,
    lastModified: now,
    changeFrequency: changeFreqByPath[path] ?? 'monthly',
    priority: priorityByPath[path] ?? 0.5,
  }))
}
