'use client'

import React, { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Alert } from '@/components/ui/alert'
import { Loader2 } from 'lucide-react'
import { useProject, useUpdateProject } from '@/lib/hooks'

interface Project {
  id: string
  name: string
  description?: string
  status: string
  progress?: number
  startDate?: string
  endDate?: string
  teamMembers?: any[]
}

export default function EditProjectPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [status, setStatus] = useState('planning')

  const { data: project, loading: projectLoading, error: projectError } = useProject(id)
  const updateProject = useUpdateProject(id)

  useEffect(() => {
    if (project) {
      setName((project as Project).name || '')
      setDescription((project as Project).description || '')
      setStatus((project as Project).status || 'planning')
    }
  }, [project])

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await updateProject.mutate({ name, description, status })
      router.push(`/projects/${id}`)
    } catch (error) {
      console.error('Failed to update project:', error)
    }
  }

  if (projectLoading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (projectError || !project) {
    return (
      <div className="p-6">
        <Alert variant="destructive">
          {t('failedToLoadProject', 'Failed to load project')}: {projectError}
        </Alert>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">{t('editProject', 'Edit Project')}</h1>
      {updateProject.error && (
        <Alert variant="destructive" className="mb-4">
          {updateProject.error}
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
          <div className="flex space-x-4">
            <Button type="submit" disabled={updateProject.loading}>
              {updateProject.loading ? t('updating', 'Updating...') : t('updateProject', 'Update Project')}
            </Button>
            <Button type="button" variant="outline" onClick={() => router.back()}>
              {t('cancel', 'Cancel')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
