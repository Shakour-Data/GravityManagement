import type { Metadata } from 'next'
import { Inter, Vazirmatn } from 'next/font/google'
import './globals.css'
import NotificationCenter from '@/components/NotificationCenter'

const inter = Inter({ subsets: ['latin'] })
const vazirmatn = Vazirmatn({ subsets: ['arabic'] })

export const metadata: Metadata = {
  title: 'GravityPM',
  description: 'Project Management Software with GitHub Integration',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="fa" dir="rtl">
      <body className={`${inter.className} ${vazirmatn.className}`}>
        <NotificationCenter />
        {children}
      </body>
    </html>
  )
}
