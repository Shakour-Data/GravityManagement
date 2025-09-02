import React, { useState } from 'react'
import { useRouter } from 'next/router'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import {
  Home,
  FolderOpen,
  CheckSquare,
  Users,
  Settings,
  GitBranch,
  Menu,
  X,
} from 'lucide-react'

interface SidebarProps {
  className?: string
}

export const Sidebar: React.FC<SidebarProps> = ({ className }) => {
  const { t, i18n } = useTranslation('common')
  const router = useRouter()
  const [isOpen, setIsOpen] = useState(false)

  const isRTL = i18n.language === 'fa'

  const menuItems = [
    { href: '/dashboard', label: t('dashboard'), icon: Home },
    { href: '/projects', label: t('projects'), icon: FolderOpen },
    { href: '/tasks', label: t('tasks'), icon: CheckSquare },
    { href: '/resources', label: t('resources'), icon: Users },
    { href: '/rules', label: t('rules'), icon: GitBranch },
    { href: '/settings', label: t('settings'), icon: Settings },
  ]

  const toggleSidebar = () => setIsOpen(!isOpen)

  return (
    <>
      {/* Mobile menu button */}
      <Button
        variant="ghost"
        size="sm"
        className="md:hidden fixed top-4 left-4 z-50"
        onClick={toggleSidebar}
      >
        {isOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
      </Button>

      {/* Overlay for mobile */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 md:hidden"
          onClick={toggleSidebar}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          'fixed top-0 left-0 z-40 h-screen w-64 bg-white border-r border-gray-200 transform transition-transform duration-300 ease-in-out md:translate-x-0',
          isRTL ? 'md:left-auto md:right-0' : '',
          isOpen ? 'translate-x-0' : '-translate-x-full',
          className
        )}
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center justify-center h-16 px-4 border-b border-gray-200">
            <h1 className="text-xl font-bold text-gray-900">
              {t('appName')}
            </h1>
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-4 py-6 space-y-2">
            {menuItems.map((item) => {
              const Icon = item.icon
              const isActive = router.pathname === item.href

              return (
                <Link key={item.href} href={item.href}>
                  <Button
                    variant={isActive ? 'secondary' : 'ghost'}
                    className={cn(
                      'w-full justify-start',
                      isRTL ? 'flex-row-reverse' : 'flex-row'
                    )}
                    onClick={() => setIsOpen(false)}
                  >
                    <Icon className="h-5 w-5 mr-3" />
                    {item.label}
                  </Button>
                </Link>
              )
            })}
          </nav>

          {/* Footer */}
          <div className="p-4 border-t border-gray-200">
            <p className="text-sm text-gray-500 text-center">
              {t('version')} 1.0.0
            </p>
          </div>
        </div>
      </aside>
    </>
  )
}
