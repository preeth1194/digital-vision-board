import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Privacy Policy',
}

const sections = [
  {
    title: 'Information We Collect',
    body: 'We collect information you provide directly, such as your name, profile picture, and habit data. We also collect device information and usage analytics to improve the app experience.',
  },
  {
    title: 'How We Use Your Information',
    body: 'Your information is used to provide and personalise the app, sync your data across devices, send reminders you have opted into, and improve our services. We do not sell your personal information to third parties.',
  },
  {
    title: 'Data Storage & Security',
    body: 'Your data is stored securely using encrypted connections. If you enable Google Drive backup, your data is encrypted before being uploaded. We use industry-standard security measures to protect your information.',
  },
  {
    title: 'Third-Party Services',
    body: 'The app may use third-party services such as Firebase for authentication and analytics, Google Drive for backups, and ad networks for free-tier users. Each third-party service has its own privacy policy governing the use of your data.',
  },
  {
    title: 'Your Rights',
    body: 'You can request deletion of your account and associated data at any time by contacting us. You may also export your data through the backup feature before deleting your account.',
  },
  {
    title: 'Changes to This Policy',
    body: 'We may update this privacy policy from time to time. We will notify you of any material changes through the app. Continued use of the app after changes constitutes acceptance of the updated policy.',
  },
  {
    title: 'Contact Us',
    body: "If you have questions or concerns about this privacy policy, please reach out to us through the app's support channels or visit our Contact page.",
  },
]

export default function PrivacyPolicyPage() {
  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-14">
      <h1 className="text-3xl sm:text-4xl font-extrabold text-forest-deep mb-2">
        Privacy Policy
      </h1>
      <p className="text-forest-deep/50 text-sm mb-10">Last updated: February 2026</p>

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
