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
import { useTask, useUpdateTask } from '@/lib/hooks'

export default function EditTaskPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [status, setStatus] = useState('todo')
  const [priority, setPriority] = useState('medium')
  const [dueDate, setDueDate] = useState('')

  // Fetch task
  const { data: task, loading: taskLoading, error: taskError } = useTask(id)
  const updateTask = useUpdateTask(id)

  // Pre-fill form when task data loads
  useEffect(() => {
    if (task) {
      setName((task as any).name || '')
      setDescription((task as any).description || '')
      setStatus((task as any).status || 'todo')
      setPriority((task as any).priority || 'medium')
      setDueDate((task as any).dueDate ? (task as any).dueDate.split('T')[0] : '')
    }
  }, [task])

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await updateTask.mutate({ name, description, status, priority, dueDate })
      router.push('/tasks')
    } catch (error) {
      console.error('Failed to update task:', error)
    }
  }

  if (taskLoading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (taskError || !task) {
    return (
      <div className="p-6">
        <Alert variant="destructive">
          {t('failedToLoadTask', 'Failed to load task')}: {taskError}
        </Alert>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <h1 className="text-3xl font-bold mb-6">{t('editTask', 'Edit Task')}</h1>
      {updateTask.error && (
        <Alert variant="destructive" className="mb-4">
          {updateTask.error}
        </Alert>
      )}
      <Card className="p-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700">
              {t('taskName', 'Task Name')}
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
            <label htmlFor="description" className="block text-sm font-medium text-gray-700">
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
            <label htmlFor="status" className="block text-sm font-medium text-gray-700">
              {t('status', 'Status')}
            </label>
            <select
              id="status"
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="todo">{t('todo', 'To Do')}</option>
              <option value="in_progress">{t('inProgress', 'In Progress')}</option>
              <option value="done">{t('done', 'Done')}</option>
            </select>
          </div>
          <div>
            <label htmlFor="priority" className="block text-sm font-medium text-gray-700">
              {t('priority', 'Priority')}
            </label>
            <select
              id="priority"
              value={priority}
              onChange={(e) => setPriority(e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="low">{t('low', 'Low')}</option>
              <option value="medium">{t('medium', 'Medium')}</option>
              <option value="high">{t('high', 'High')}</option>
            </select>
          </div>
          <div>
            <label htmlFor="dueDate" className="block text-sm font-medium text-gray-700">
              {t('dueDate', 'Due Date')}
            </label>
            <Input
              id="dueDate"
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
            />
          </div>
          <div>
            <Button type="submit" disabled={updateTask.loading}>
              {updateTask.loading ? t('updating', 'Updating...') : t('updateTask', 'Update Task')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
