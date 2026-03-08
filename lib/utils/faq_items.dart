class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

const List<FaqItem> kFaqItems = [
  FaqItem(
    question: 'How do I sign in or create an account?',
    answer:
        'Open Sign In from the profile area. You can continue with Google or create an account with email and password.',
  ),
  FaqItem(
    question: 'Can I use the app without signing in?',
    answer:
        'Yes. Guest mode works for trying features. Signing in is recommended to keep your data tied to your account.',
  ),
  FaqItem(
    question: 'How does backup and restore work?',
    answer:
        'Use Backup & Restore from the app menu. Backups are encrypted before upload and can be restored on a new device.',
  ),
  FaqItem(
    question: 'Will my habits and journal entries sync automatically?',
    answer:
        'Auto-sync can run in the background when enabled. You can also trigger manual sync anytime from the menu.',
  ),
  FaqItem(
    question: 'How do subscriptions work?',
    answer:
        'Premium plans are managed through your app store account. You can view your current plan in the Subscription screen.',
  ),
  FaqItem(
    question: 'What is the Preset Shop?',
    answer:
        'Preset Shop provides ready-made templates and packs to help you start routines faster.',
  ),
  FaqItem(
    question: 'How do I report a bug?',
    answer:
        'Open Report Issue from the menu, add summary and details, then submit. Your report appears in My Issues with status updates.',
  ),
  FaqItem(
    question: 'What do issue statuses mean?',
    answer:
        'Open means received, In Progress means currently being worked on, and Resolved means a fix or answer was completed.',
  ),
  FaqItem(
    question: 'How can I contact support for general questions?',
    answer:
        'Open Contact Us from the menu and send your message. Include as much detail as possible for a faster response.',
  ),
  FaqItem(
    question: 'How long does support usually take to reply?',
    answer:
        'Most requests are reviewed within 2 to 3 business days. Complex issues may take longer when extra investigation is needed.',
  ),
];
