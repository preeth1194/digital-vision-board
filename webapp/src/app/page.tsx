import Link from 'next/link'
import { APP_NAME, APP_TAGLINE, APP_DESCRIPTION, PLAY_STORE_URL, APP_STORE_URL } from '@/lib/constants'

const features = [
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
      </svg>
    ),
    title: 'Vision Boards',
    description: 'Design stunning visual goal boards with images, affirmations, and dream collages that keep you inspired every day.',
    color: 'from-sprout/20 to-sprout/5',
    iconBg: 'bg-sprout/20 text-sprout-dark',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    title: 'Daily Habits',
    description: 'Build powerful routines with habit tracking, streaks, and step-by-step action plans that turn intentions into results.',
    color: 'from-blue-100 to-blue-50',
    iconBg: 'bg-blue-100 text-blue-700',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
      </svg>
    ),
    title: 'Guided Journal',
    description: 'Reflect, grow, and celebrate wins with prompted journaling, mood tracking, and personal insights over time.',
    color: 'from-purple-100 to-purple-50',
    iconBg: 'bg-purple-100 text-purple-700',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    title: 'Smart Routines',
    description: 'Plan morning, evening, and custom routines with timers and checklists that keep you on track all day long.',
    color: 'from-amber-100 to-amber-50',
    iconBg: 'bg-amber-100 text-amber-700',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.047 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 18a3.75 3.75 0 00.495-7.467 5.99 5.99 0 00-1.925 3.546 5.974 5.974 0 01-2.133-1A3.75 3.75 0 0012 18z" />
      </svg>
    ),
    title: 'Affirmations',
    description: 'Rewire your mindset with powerful daily affirmations, custom mantras, and positive self-talk practices.',
    color: 'from-pink-100 to-pink-50',
    iconBg: 'bg-pink-100 text-pink-700',
  },
  {
    icon: (
      <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 010 3.75H5.625a1.875 1.875 0 010-3.75z" />
      </svg>
    ),
    title: 'Preset Library',
    description: 'Jumpstart any wellness goal with community-curated habit presets for skincare, workouts, meal prep, and recipes.',
    color: 'from-teal-100 to-teal-50',
    iconBg: 'bg-teal-100 text-teal-700',
  },
]

export default function HomePage() {
  return (
    <div className="flex flex-col">
      {/* Hero */}
      <section className="relative overflow-hidden bg-hero-gradient min-h-[580px] flex items-center">
        <div
          className="absolute inset-0 opacity-10"
          style={{
            backgroundImage: `radial-gradient(circle at 20% 50%, #4CAF50 0%, transparent 50%),
              radial-gradient(circle at 80% 20%, #4CAF50 0%, transparent 40%)`,
          }}
        />
        <div className="relative max-w-6xl mx-auto px-4 sm:px-6 py-20 text-center">
          <div className="inline-flex items-center gap-2 bg-sprout/20 text-sprout px-4 py-1.5 rounded-full text-sm font-medium mb-6 border border-sprout/30">
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M17 8C8 10 5.9 16.17 3.82 22c4.36-3.16 8.77-3.77 13.18-3.91V22l4-6-4-5.09V8z" />
            </svg>
            Available on iOS &amp; Android
          </div>

          <h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold text-white mb-6 leading-tight text-balance">
            {APP_TAGLINE}
          </h1>
          <p className="text-mist/70 text-lg sm:text-xl max-w-2xl mx-auto mb-10 leading-relaxed">
            {APP_DESCRIPTION}
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={APP_STORE_URL}
              className="flex items-center gap-3 bg-white text-forest-deep font-semibold px-6 py-3.5 rounded-xl hover:bg-mist transition-all shadow-lg hover:shadow-xl group"
            >
              <svg className="w-6 h-6 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98l-.09.06c-.22.15-2.19 1.28-2.17 3.83.03 3.02 2.65 4.03 2.68 4.04l-.06.25zM13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              <div className="text-left">
                <div className="text-xs opacity-70">Download on the</div>
                <div className="text-base leading-tight">App Store</div>
              </div>
            </a>

            <a
              href={PLAY_STORE_URL}
              className="flex items-center gap-3 bg-white text-forest-deep font-semibold px-6 py-3.5 rounded-xl hover:bg-mist transition-all shadow-lg hover:shadow-xl group"
            >
              <svg className="w-6 h-6 flex-shrink-0" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3 20.5v-17c0-.83.94-1.3 1.6-.8l14 8.5c.6.36.6 1.24 0 1.6l-14 8.5c-.66.5-1.6.03-1.6-.8z" />
              </svg>
              <div className="text-left">
                <div className="text-xs opacity-70">Get it on</div>
                <div className="text-base leading-tight">Google Play</div>
              </div>
            </a>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 px-4 sm:px-6 bg-mist">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-14">
            <h2 className="text-3xl sm:text-4xl font-bold text-forest-deep mb-4">
              Everything you need to thrive
            </h2>
            <p className="text-forest-deep/60 text-lg max-w-xl mx-auto">
              One beautifully integrated app for your goals, habits, and well-being.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map((feature) => (
              <div
                key={feature.title}
                className={`bg-gradient-to-br ${feature.color} rounded-2xl p-6 border border-white/60 shadow-sm hover:shadow-md transition-all`}
              >
                <div className={`w-12 h-12 rounded-xl ${feature.iconBg} flex items-center justify-center mb-4`}>
                  {feature.icon}
                </div>
                <h3 className="text-forest-deep font-bold text-lg mb-2">{feature.title}</h3>
                <p className="text-forest-deep/60 text-sm leading-relaxed">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 px-4 sm:px-6 bg-forest-deep">
        <div className="max-w-3xl mx-auto text-center">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            Ready to grow?
          </h2>
          <p className="text-mist/60 text-lg mb-8">
            Join thousands of people who are already building the lives they imagined.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={APP_STORE_URL}
              className="bg-sprout text-forest-deep font-bold px-8 py-3.5 rounded-xl hover:bg-sprout-light transition-all shadow-lg text-lg"
            >
              Download Free
            </a>
            <Link
              href="/sign-up"
              className="border border-sprout/40 text-sprout font-semibold px-8 py-3.5 rounded-xl hover:bg-sprout/10 transition-all text-lg"
            >
              Create Account
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}
