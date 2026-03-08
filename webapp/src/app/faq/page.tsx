import type { Metadata } from 'next'
import { FAQ_ITEMS } from '@/lib/faq'

export const metadata: Metadata = {
  title: 'FAQ',
  description: 'Frequently asked questions about Habit Seeding accounts, sync, subscriptions, and support.',
}

export default function FaqPage() {
  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-12">
      <div className="mb-8">
        <h1 className="text-3xl font-extrabold text-forest-deep">Frequently Asked Questions</h1>
        <p className="mt-2 text-forest-deep/70">
          Quick answers about accounts, sync, subscriptions, and support.
        </p>
      </div>

      <div className="space-y-3">
        {FAQ_ITEMS.map((item) => (
          <details key={item.question} className="bg-white rounded-2xl border border-forest-deep/10 p-5 shadow-sm group">
            <summary className="cursor-pointer list-none font-semibold text-forest-deep flex items-start justify-between gap-3">
              <span>{item.question}</span>
              <span className="text-sprout-dark transition-transform group-open:rotate-45" aria-hidden>
                +
              </span>
            </summary>
            <p className="mt-3 text-sm leading-relaxed text-forest-deep/80">{item.answer}</p>
          </details>
        ))}
      </div>
    </div>
  )
}
