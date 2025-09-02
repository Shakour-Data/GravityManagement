import React from 'react'
import { useRouter } from 'next/router'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import { ChevronRight, Home } from 'lucide-react'

interface BreadcrumbItem {
  label: string
  href?: string
}

interface BreadcrumbProps {
  items: BreadcrumbItem[]
  className?: string
}

export const Breadcrumb: React.FC<BreadcrumbProps> = ({ items, className }) => {
  const { t, i18n } = useTranslation('common')
  const router = useRouter()
  const isRTL = i18n.language === 'fa'

  return (
    <nav
      className={cn(
        'flex items-center space-x-2 text-sm text-gray-600',
        isRTL ? 'space-x-reverse' : '',
        className
      )}
      aria-label="Breadcrumb"
    >
      {/* Home link */}
      <Link
        href="/dashboard"
        className="flex items-center hover:text-gray-900 transition-colors"
      >
        <Home className="h-4 w-4" />
        <span className="sr-only">{t('home')}</span>
      </Link>

      {/* Separator */}
      <ChevronRight
        className={cn(
          'h-4 w-4 text-gray-400',
          isRTL ? 'rotate-180' : ''
        )}
      />

      {/* Breadcrumb items */}
      {items.map((item, index) => (
        <React.Fragment key={index}>
          {item.href ? (
            <Link
              href={item.href}
              className="hover:text-gray-900 transition-colors"
            >
              {item.label}
            </Link>
          ) : (
            <span className="text-gray-900 font-medium" aria-current="page">
              {item.label}
            </span>
          )}

          {/* Separator (not for last item) */}
          {index < items.length - 1 && (
            <ChevronRight
              className={cn(
                'h-4 w-4 text-gray-400',
                isRTL ? 'rotate-180' : ''
              )}
            />
          )}
        </React.Fragment>
      ))}
    </nav>
  )
}
