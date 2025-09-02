'use client'

import React from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Alert } from '@/components/ui/alert'
import { Loader2, Edit, Trash2, ArrowLeft, Calendar, CheckCircle } from 'lucide-react'
import { useTask } from '@/lib/hooks'
import TaskDependencies from '@/components/TaskDependencies'

interface Task {
  id: string
  name: string
  description?: string
  status: string
  priority: string
  dueDate?: string
  progress?: number
  createdAt?: string
  updatedAt?: string
}

export default function TaskDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  // Fetch task
  const { data: task, loading, error } = useTask(id) as { data: Task | null, loading: boolean, error: string | null }

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (error || !task) {
    return (
      <div className="p-6">
        <Alert variant="destructive">
          {t('failedToLoadTask', 'Failed to load task')}: {error}
        </Alert>
        <Button onClick={() => router.back()} className="mt-4">
          <ArrowLeft className="h-4 w-4 mr-2" />
          {t('back', 'Back')}
        </Button>
      </div>
    )
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-4">
          <Button onClick={() => router.back()} variant="outline">
            <ArrowLeft className="h-4 w-4 mr-2" />
            {t('back', 'Back')}
          </Button>
          <h1 className="text-3xl font-bold">{task?.name}</h1>
        </div>
        <div className="flex space-x-2">
          <Link href={`/tasks/${id}/edit`}>
            <Button variant="outline">
              <Edit className="h-4 w-4 mr-2" />
              {t('edit', 'Edit')}
            </Button>
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        {/* Task Info */}
        <Card className="p-6 lg:col-span-2">
          <h2 className="text-xl font-semibold mb-4">{t('taskDetails', 'Task Details')}</h2>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium text-gray-600">{t('description', 'Description')}</label>
              <p className="mt-1">{task?.description || t('noDescription', 'No description provided')}</p>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('status', 'Status')}</label>
                <div className="mt-1">
                  <Badge variant={
                    task?.status === 'done' ? 'default' :
                    task?.status === 'in_progress' ? 'secondary' :
                    'outline'
                  }>
                    {task?.status}
                  </Badge>
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('priority', 'Priority')}</label>
                <div className="mt-1">
                  <Badge variant={
                    task?.priority === 'high' ? 'destructive' :
                    task?.priority === 'medium' ? 'default' :
                    'secondary'
                  }>
                    {task?.priority}
                  </Badge>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="flex items-center space-x-2">
                <Calendar className="h-4 w-4 text-gray-500" />
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('dueDate', 'Due Date')}</label>
                  <p className="text-sm">{task?.dueDate ? new Date(task.dueDate).toLocaleDateString() : t('notSet', 'Not set')}</p>
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('progress', 'Progress')}</label>
                <div className="mt-1 flex items-center space-x-2">
                  <Progress value={task?.progress || 0} className="flex-1" />
                  <span className="text-sm">{task?.progress || 0}%</span>
                </div>
              </div>
            </div>
          </div>
        </Card>

        {/* Quick Stats */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('quickStats', 'Quick Stats')}</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <CheckCircle className="h-5 w-5 text-green-500" />
                <span className="text-sm">{t('progress', 'Progress')}</span>
              </div>
              <span className="font-semibold">{task?.progress || 0}%</span>
            </div>
          </div>
        </Card>
      </div>

      {/* Task Dependencies */}
      <TaskDependencies taskId={id} />
    </div>
  )
}
