import React from 'react'
import { useTranslation } from 'next-i18next'
import { cn } from '@/lib/utils'

interface FooterProps {
  className?: string
}

export const Footer: React.FC<FooterProps> = ({ className }) => {
  const { t, i18n } = useTranslation('common')
  const isRTL = i18n.language === 'fa'

  return (
    <footer
      className={cn(
        'bg-white border-t border-gray-200 px-4 py-6',
        className
      )}
    >
      <div className="max-w-7xl mx-auto">
        <div className={cn(
          'flex flex-col md:flex-row justify-between items-center space-y-4 md:space-y-0',
          isRTL ? 'md:flex-row-reverse' : ''
        )}>
          {/* Copyright */}
          <div className="text-sm text-gray-500">
            © 2024 {t('appName')}. {t('allRightsReserved')}
          </div>

          {/* Links */}
          <div className={cn(
            'flex space-x-6 text-sm text-gray-500',
            isRTL ? 'space-x-reverse' : ''
          )}>
            <a href="#" className="hover:text-gray-700 transition-colors">
              {t('privacyPolicy')}
            </a>
            <a href="#" className="hover:text-gray-700 transition-colors">
              {t('termsOfService')}
            </a>
            <a href="#" className="hover:text-gray-700 transition-colors">
              {t('contact')}
            </a>
          </div>
        </div>
      </div>
    </footer>
  )
}
