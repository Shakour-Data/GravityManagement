'use client'

import React, { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { z } from 'zod'
import { Form, FormField } from '@/components/forms'
import { Button } from '@/components/ui/button'
import { Alert } from '@/components/ui/alert'
import { apiClient } from '@/lib/api'

const loginSchema = z.object({
  email: z.string().email({ message: 'Invalid email address' }),
  password: z.string().min(6, { message: 'Password must be at least 6 characters' }),
})

export default function LoginPage() {
  const { t } = useTranslation('common')
  const router = useRouter()
  const searchParams = useSearchParams()
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const successMessage = searchParams.get('message')

  const onSubmit = async (data: any) => {
    setIsLoading(true)
    setError(null)

    try {
      // Implement authentication logic with backend
      const response = await apiClient.login(data)
      if (response.data.token) {
        router.push('/dashboard')
      } else {
        setError('Login failed. Please check your credentials.')
      }
    } catch (err) {
      setError('Login failed. Please check your credentials.')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="max-w-md mx-auto mt-20 p-6 bg-white rounded-md shadow-md">
      <h1 className="text-2xl font-bold mb-6">{t('login')}</h1>

      {successMessage && (
        <Alert className="mb-4">
          {successMessage}
        </Alert>
      )}

      {error && (
        <Alert className="mb-4" variant="destructive">
          {error}
        </Alert>
      )}

      <Form onSubmit={onSubmit} schema={loginSchema}>
        <FormField name="email" label={t('email')} type="email" required />
        <FormField name="password" label={t('password')} type="password" required />
        <div className="mt-6 flex justify-between">
          <Button type="submit" disabled={isLoading}>
            {isLoading ? t('loggingIn') : t('login')}
          </Button>
          <Button variant="ghost" onClick={() => router.push('/auth/register')}>
            {t('register')}
          </Button>
        </div>
      </Form>
    </div>
  )
}
