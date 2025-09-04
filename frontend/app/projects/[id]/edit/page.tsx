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
  name?: string
  description?: string
  status?: string
  startDate?: string
  endDate?: string
  budget?: number
}

export default function EditProjectPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [status, setStatus] = useState('planning')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [budget, setBudget] = useState('')

  // Fetch existing project data
  const { data: project, loading: projectLoading, error: projectError } = useProject(id)
  const updateProject = useUpdateProject(id)

  // Populate form when project data is loaded
  useEffect(() => {
    if (project) {
      const typedProject = project as Project
      setName(typedProject.name || '')
      setDescription(typedProject.description || '')
      setStatus(typedProject.status || 'planning')
      setStartDate(typedProject.startDate ? new Date(typedProject.startDate).toISOString().split('T')[0] : '')
      setEndDate(typedProject.endDate ? new Date(typedProject.endDate).toISOString().split('T')[0] : '')
      setBudget(typedProject.budget?.toString() || '')
    }
  }, [project])

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await updateProject.mutate({
        name,
        description,
        status,
        startDate: startDate ? new Date(startDate).toISOString() : undefined,
        endDate: endDate ? new Date(endDate).toISOString() : undefined,
        budget: budget ? parseFloat(budget) : undefined
      })
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
        <Button onClick={() => router.back()} className="mt-4">
          {t('back', 'Back')}
        </Button>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('editProject', 'Edit Project')}</h1>
        <Button variant="outline" onClick={() => router.back()}>
          {t('cancel', 'Cancel')}
        </Button>
      </div>

      {updateProject.error && (
        <Alert variant="destructive" className="mb-4">
          {updateProject.error}
        </Alert>
      )}

      <Card className="p-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
              {t('projectName', 'Project Name')} *
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
            <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-2">
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
            <label htmlFor="status" className="block text-sm font-medium text-gray-700 mb-2">
              {t('status', 'Status')}
            </label>
            <select
              id="status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="planning">{t('planning', 'Planning')}</option>
              <option value="active">{t('active', 'Active')}</option>
              <option value="on-hold">{t('onHold', 'On Hold')}</option>
              <option value="completed">{t('completed', 'Completed')}</option>
              <option value="cancelled">{t('cancelled', 'Cancelled')}</option>
            </select>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="startDate" className="block text-sm font-medium text-gray-700 mb-2">
                {t('startDate', 'Start Date')}
              </label>
              <Input
                id="startDate"
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
              />
            </div>

            <div>
              <label htmlFor="endDate" className="block text-sm font-medium text-gray-700 mb-2">
                {t('endDate', 'End Date')}
              </label>
              <Input
                id="endDate"
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label htmlFor="budget" className="block text-sm font-medium text-gray-700 mb-2">
              {t('budget', 'Budget')} ({t('currency', 'USD')})
            </label>
            <Input
              id="budget"
              type="number"
              step="0.01"
              value={budget}
              onChange={(e) => setBudget(e.target.value)}
              placeholder={t('enterBudget', 'Enter project budget')}
            />
          </div>

          <div className="flex space-x-4">
            <Button
              type="submit"
              disabled={updateProject.loading}
              className="flex-1"
            >
              {updateProject.loading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  {t('updating', 'Updating...')}
                </>
              ) : (
                t('updateProject', 'Update Project')
              )}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
              className="flex-1"
            >
              {t('cancel', 'Cancel')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
