'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { z } from 'zod'
import { Form, FormField } from '@/components/forms'
import { Button } from '@/components/ui/button'
import { Alert } from '@/components/ui/alert'

const registerSchema = z.object({
  name: z.string().min(2, { message: 'Name must be at least 2 characters' }),
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
  confirmPassword: z.string(),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
})

export default function RegisterPage() {
  const { t } = useTranslation('common')
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const onSubmit = async (data: any) => {
    setIsLoading(true)
    setError(null)

    try {
      // TODO: Implement registration logic with backend
      console.log('Registration data:', data)

      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000))

      // On success, redirect to login
      router.push('/auth/login?message=Registration successful')
    } catch (err) {
      setError('Registration failed. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto mt-20 p-6 bg-white rounded-md shadow-md">
      <h1 className="text-2xl font-bold mb-6">{t('register')}</h1>

      {error && (
        <Alert className="mb-4" variant="destructive">
          {error}
        </Alert>
      )}

      <Form onSubmit={onSubmit} schema={registerSchema}>
        <FormField name="name" label={t('name')} required />
        <FormField name="email" label={t('email')} type="email" required />
        <FormField name="password" label={t('password')} type="password" required />
        <FormField name="confirmPassword" label={t('confirmPassword')} type="password" required />

        <div className="mt-6 flex justify-between">
          <Button type="submit" disabled={isLoading}>
            {isLoading ? t('registering') : t('register')}
          </Button>
          <Button variant="ghost" onClick={() => router.push('/auth/login')}>
            {t('backToLogin')}
          </Button>
        </div>
      </Form>
    </div>
  )
}
