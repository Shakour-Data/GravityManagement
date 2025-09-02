'use client'

import React from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { z } from 'zod'
import { Form, FormField } from '@/components/forms'
import { Button } from '@/components/ui/button'

const loginSchema = z.object({
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
})

export default function LoginPage() {
  const { t } = useTranslation('common')
  const router = useRouter()

  const onSubmit = (data: any) => {
    // TODO: Implement authentication logic with backend
    console.log('Login data:', data)
    router.push('/dashboard')
  }

  return (
    <div className="max-w-md mx-auto mt-20 p-6 bg-white rounded-md shadow-md">
      <h1 className="text-2xl font-bold mb-6">{t('login')}</h1>
      <Form onSubmit={onSubmit} schema={loginSchema}>
        <FormField name="email" label={t('email')} required />
        <FormField name="password" label={t('password')} type="password" required />
        <div className="mt-6 flex justify-between">
          <Button type="submit">{t('login')}</Button>
          <Button variant="ghost" onClick={() => router.push('/auth/register')}>
            {t('register')}
          </Button>
        </div>
      </Form>
    </div>
  )
}
