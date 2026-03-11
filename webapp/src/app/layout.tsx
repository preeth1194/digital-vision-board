import type { Metadata } from 'next'
import './globals.css'
import Header from '@/components/Header'
import Footer from '@/components/Footer'
import { APP_NAME, APP_DESCRIPTION } from '@/lib/constants'
import { getSiteUrl } from '@/lib/seo'

const siteUrl = getSiteUrl()
const googleVerification = process.env.GOOGLE_SITE_VERIFICATION?.trim()
const bingVerification = process.env.BING_SITE_VERIFICATION?.trim()

const verification: Metadata['verification'] = {
  ...(googleVerification ? { google: googleVerification } : {}),
  ...(bingVerification ? { other: { 'msvalidate.01': bingVerification } } : {}),
}

export const metadata: Metadata = {
  title: {
    default: APP_NAME,
    template: `%s | ${APP_NAME}`,
  },
  description: APP_DESCRIPTION,
  metadataBase: new URL(siteUrl),
  icons: {
    icon: '/app-icon.png',
    apple: '/app-icon.png',
  },
  ...(Object.keys(verification).length ? { verification } : {}),
  openGraph: {
    title: APP_NAME,
    description: APP_DESCRIPTION,
    type: 'website',
    url: siteUrl,
    images: [{ url: '/app-icon.png' }],
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-screen flex flex-col bg-mist">
        <Header />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  )
}
