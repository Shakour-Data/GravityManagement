'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Alert } from '@/components/ui/alert'
import { useCreateProject } from '@/lib/hooks'
import { FileUpload } from '@/components/FileUpload'

export default function CreateProjectPage() {
  const { t } = useTranslation('common')
  const router = useRouter()

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [status, setStatus] = useState('planning')

  const createProject = useCreateProject()

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await createProject.mutate({ name, description, status })
      router.push('/projects')
    } catch (error) {
      console.error('Failed to create project:', error)
    }
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">{t('createProject', 'Create Project')}</h1>
      {createProject.error && (
        <Alert variant="destructive" className="mb-4">
          {createProject.error}
        </Alert>
      )}
      <Card className="p-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700">
              {t('projectName', 'Project Name')}
            </label>
            <Input
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder={t('enterProjectName', 'Enter project name')}
            />
          </div>
          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700">
              {t('description', 'Description')}
            </label>
            <Textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder={t('enterProjectDescription', 'Enter project description')}
              rows={4}
            />
          </div>
          <div>
            <label htmlFor="status" className="block text-sm font-medium text-gray-700">
              {t('status', 'Status')}
            </label>
            <select
              id="status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="planning">{t('planning', 'Planning')}</option>
              <option value="active">{t('active', 'Active')}</option>
              <option value="on-hold">{t('onHold', 'On Hold')}</option>
              <option value="completed">{t('completed', 'Completed')}</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              {t('attachments', 'Attachments')}
            </label>
            <FileUpload onFilesUploaded={(files) => console.log('Files uploaded:', files)} />
          </div>
          <div>
            <Button type="submit" disabled={createProject.loading}>
              {createProject.loading ? t('creating', 'Creating...') : t('createProject', 'Create Project')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
