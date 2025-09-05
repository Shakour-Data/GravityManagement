import type { Metadata } from 'next'
import { Inter, Vazirmatn } from 'next/font/google'
import './globals.css'
import NotificationCenter from '@/components/NotificationCenter'
import { AdvancedSearch } from '@/components/AdvancedSearch'

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
        <header className="bg-white shadow-sm border-b">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-4">
              <h1 className="text-2xl font-bold text-gray-900">GravityPM</h1>
              <div className="w-96">
                <AdvancedSearch onSearch={(filters) => console.log('Search:', filters)} />
              </div>
            </div>
          </div>
        </header>
        <NotificationCenter />
        {children}
      </body>
    </html>
  )
}
