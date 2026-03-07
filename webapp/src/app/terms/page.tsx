import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Terms & Conditions',
}

const sections = [
  {
    title: 'Acceptance of Terms',
    body: 'By using Habit Seeding, you agree to these terms. If you do not agree, please do not use the app.',
  },
  {
    title: 'Use of the App',
    body: 'You agree to use the app lawfully and responsibly. You must not misuse, disrupt, or attempt unauthorized access to the app or related services.',
  },
  {
    title: 'Accounts and Guest Access',
    body: 'You may use the app as a guest or sign in with supported providers. You are responsible for activities under your account or guest profile on your device.',
  },
  {
    title: 'Content and Data',
    body: 'You retain ownership of your personal content (habits, journal entries, routines, and related data). You grant us a limited license to process this data solely to operate and improve app features.',
  },
  {
    title: 'Subscriptions and Ads',
    body: 'Some features may require subscriptions, and free-tier use may include ads. Billing terms for subscriptions are managed by the platform app store and may be subject to its policies.',
  },
  {
    title: 'Disclaimers',
    body: 'The app is provided "as is" without warranties of any kind. Habit Seeding is a productivity and wellness tool and is not a medical or emergency service.',
  },
  {
    title: 'Limitation of Liability',
    body: 'To the maximum extent permitted by law, we are not liable for indirect, incidental, or consequential damages arising from use of the app.',
  },
  {
    title: 'Changes to Terms',
    body: 'We may update these terms from time to time. Continued use of the app after updates constitutes acceptance of the revised terms.',
  },
]

export default function TermsPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-14">
      <h1 className="text-3xl sm:text-4xl font-extrabold text-forest-deep mb-2">
        Terms &amp; Conditions
      </h1>
      <p className="text-forest-deep/50 text-sm mb-10">Last updated: March 2026</p>

      <div className="space-y-8">
        {sections.map((s) => (
          <div key={s.title}>
            <h2 className="text-lg font-bold text-forest-deep mb-2">{s.title}</h2>
            <p className="text-forest-deep/70 leading-relaxed">{s.body}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
