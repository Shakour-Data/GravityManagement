'use client'

import React from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { z } from 'zod'
import { Form, FormField } from '@/components/forms'
import { Button } from '@/components/ui/button'

const registerSchema = z.object({
  name: z.string().min(1, { message: 'Name is required' }),
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
  confirmPassword: z.string().min(6, { message: 'Confirm password is required' }),
}).refine((data) => data.password === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
})

export default function RegisterPage() {
  const { t } = useTranslation('common')
  const router = useRouter()

  const onSubmit = (data: any) => {
    // TODO: Implement registration logic with backend
    console.log('Register data:', data)
    router.push('/auth/login')
  }

  return (
    <div className="max-w-md mx-auto mt-20 p-6 bg-white rounded-md shadow-md">
      <h1 className="text-2xl font-bold mb-6">{t('register')}</h1>
      <Form onSubmit={onSubmit} schema={registerSchema}>
        <FormField name="name" label={t('name')} required />
        <FormField name="email" label={t('email')} required />
        <FormField name="password" label={t('password')} type="password" required />
        <FormField name="confirmPassword" label={t('confirmPassword')} type="password" required />
        <div className="mt-6 flex justify-between">
          <Button type="submit">{t('register')}</Button>
          <Button variant="ghost" onClick={() => router.push('/auth/login')}>
            {t('login')}
          </Button>
        </div>
      </Form>
    </div>
  )
}
