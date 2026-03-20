# Webapp Page Skill

Create a new Next.js 14 page or component for the Digital Vision Board webapp.

## Instructions

### 1. File Location & Routing

The webapp uses the **App Router** (`webapp/src/app/`). File-system routing applies:

```
webapp/src/app/
├── page.tsx              # /
├── sign-in/page.tsx      # /sign-in
├── profile/page.tsx      # /profile
├── admin/presets/page.tsx # /admin/presets
├── presets/page.tsx       # /presets
└── api/
    └── backend/[...path]/route.ts  # backend proxy
```

Shared components → `webapp/src/components/`
Utilities → `webapp/src/lib/`
Types → `webapp/src/types/`

### 2. TypeScript Rules

- All files use `.tsx` (components) or `.ts` (utilities)
- Use strict TypeScript — no `any` unless absolutely unavoidable
- Use the path alias: `import { X } from '@/components/X'` (maps to `src/`)
- Define prop interfaces inline or in `webapp/src/types/`

### 3. Page Component Pattern

```tsx
// app/my-feature/page.tsx
import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Feature Name — Digital Vision Board',
  description: 'Brief description for SEO',
};

export default function MyFeaturePage() {
  return (
    <main className="min-h-screen bg-[#F6F4EF]">
      {/* content */}
    </main>
  );
}
```

### 4. Authentication

Use Firebase auth via `webapp/src/lib/firebase/`:
```tsx
import { auth } from '@/lib/firebase/client';
import { getSession } from '@/lib/session';

// Server component: check session
const session = await getSession();
if (!session) redirect('/sign-in');

// Client component: use Firebase auth state
import { useAuthState } from 'react-firebase-hooks/auth';
const [user, loading] = useAuthState(auth);
```

### 5. Backend API Calls

Use the backend lib helpers (`webapp/src/lib/backend/`), not raw `fetch`:
```tsx
import { backendGet, backendPost } from '@/lib/backend';

const data = await backendGet('/api/my-endpoint', session.token);
await backendPost('/api/my-endpoint', payload, session.token);
```

Or via the proxy route at `/api/backend/[...path]`.

### 6. Styling

Use **Tailwind CSS** utility classes. Follow the Morning Garden colour mapping:

| Visual Purpose | Tailwind Class |
|---|---|
| Page background (warm cream) | `bg-[#F6F4EF]` |
| Primary action / button | `bg-[#4A7A5A]` |
| Primary text on button | `text-white` |
| Navigation / header bg | `bg-[#3B2D20]` |
| Coin / badge icon | `text-[#C48B3C]` |
| Amber reward **text** | `text-[#7A5520]` |
| Card surface | `bg-white dark:bg-[#1F2B22]` |
| Lavender (mood/journal) | `text-[#7B74A8]` |
| Chip / tag background | `bg-[#DCF0E4]` |

Use `rounded-3xl` for cards (`radiusCard = 24px`), `rounded-xl` for inputs/buttons.

### 7. Font

Inter is loaded globally via `layout.tsx`. Use `font-sans` — do not import Google Fonts again.

### 8. Server vs Client Components

- Default to **Server Components** (no `'use client'` directive)
- Add `'use client'` only when using hooks, event handlers, or browser APIs
- Fetch data in Server Components; pass as props to Client Components

### 9. SEO

Export `metadata` from every page:
```tsx
export const metadata: Metadata = {
  title: '...',
  description: '...',
  openGraph: { title: '...', description: '...', ... },
};
```

### 10. Admin Pages

Admin pages must verify admin status server-side before rendering:
```tsx
const session = await getSession();
if (!session?.isAdmin) redirect('/');
```

---

## Task

Create the webapp page or component described in `$ARGUMENTS`.

- State the exact file path
- Write complete TypeScript/TSX code
- Include metadata export for pages
- Follow Tailwind Morning Garden colour conventions
- Note any new backend API endpoints required
