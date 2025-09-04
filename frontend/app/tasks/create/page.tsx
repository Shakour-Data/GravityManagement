'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Alert } from '@/components/ui/alert'
import { Loader2 } from 'lucide-react'
import { useCreateTask, useProjects } from '@/lib/hooks'

export default function CreateTaskPage() {
  const { t } = useTranslation('common')
  const router = useRouter()

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [projectId, setProjectId] = useState('')
  const [priority, setPriority] = useState('medium')
  const [dueDate, setDueDate] = useState('')
  const [estimatedHours, setEstimatedHours] = useState('')

  const createTask = useCreateTask()
  const { data: projects, loading: projectsLoading } = useProjects()

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await createTask.mutate({
        name,
        description,
        project_id: projectId,
        priority,
        due_date: dueDate ? new Date(dueDate).toISOString() : undefined,
        estimated_hours: estimatedHours ? parseFloat(estimatedHours) : undefined
      })
      router.push('/tasks')
    } catch (error) {
      console.error('Failed to create task:', error)
    }
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('createTask', 'Create Task')}</h1>
        <Button variant="outline" onClick={() => router.back()}>
          {t('cancel', 'Cancel')}
        </Button>
      </div>

      {createTask.error && (
        <Alert variant="destructive" className="mb-4">
          {createTask.error}
        </Alert>
      )}

      <Card className="p-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
              {t('taskName', 'Task Name')} *
            </label>
            <Input
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder={t('enterTaskName', 'Enter task name')}
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
              placeholder={t('enterTaskDescription', 'Enter task description')}
              rows={4}
            />
          </div>

          <div>
            <label htmlFor="project" className="block text-sm font-medium text-gray-700 mb-2">
              {t('project', 'Project')} *
            </label>
            <Select value={projectId} onValueChange={setProjectId}>
              <SelectTrigger>
                <SelectValue placeholder={t('selectProject', 'Select a project')} />
              </SelectTrigger>
              <SelectContent>
                {projectsLoading ? (
                  <SelectItem value="" disabled>
                    {t('loading', 'Loading...')}
                  </SelectItem>
                ) : (
                  (projects as any[])?.map((project: any) => (
                    <SelectItem key={project.id} value={project.id}>
                      {project.name}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="priority" className="block text-sm font-medium text-gray-700 mb-2">
                {t('priority', 'Priority')}
              </label>
              <Select value={priority} onValueChange={setPriority}>
                <SelectTrigger>
                  <SelectValue placeholder={t('selectPriority', 'Select priority')} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="low">{t('low', 'Low')}</SelectItem>
                  <SelectItem value="medium">{t('medium', 'Medium')}</SelectItem>
                  <SelectItem value="high">{t('high', 'High')}</SelectItem>
                  <SelectItem value="urgent">{t('urgent', 'Urgent')}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <label htmlFor="dueDate" className="block text-sm font-medium text-gray-700 mb-2">
                {t('dueDate', 'Due Date')}
              </label>
              <Input
                id="dueDate"
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label htmlFor="estimatedHours" className="block text-sm font-medium text-gray-700 mb-2">
              {t('estimatedHours', 'Estimated Hours')}
            </label>
            <Input
              id="estimatedHours"
              type="number"
              step="0.5"
              value={estimatedHours}
              onChange={(e) => setEstimatedHours(e.target.value)}
              placeholder={t('enterEstimatedHours', 'Enter estimated hours')}
            />
          </div>

          <div className="flex space-x-4">
            <Button
              type="submit"
              disabled={createTask.loading || !projectId}
              className="flex-1"
            >
              {createTask.loading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  {t('creating', 'Creating...')}
                </>
              ) : (
                t('createTask', 'Create Task')
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
