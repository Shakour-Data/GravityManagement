'use client'

import React, { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Alert } from '@/components/ui/alert'
import { Loader2, Edit, Trash2, ArrowLeft, Calendar, Users, CheckCircle } from 'lucide-react'
import { useProject, useTasks, useDeleteProject, useRealtimeUpdates } from '@/lib/hooks'
import { Chart } from '@/components/ui/chart'
import WBSTree from '@/components/WBSTree'

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

interface Task {
  id: string
  name: string
  description?: string
  status: string
  priority: string
  dueDate?: string
  progress?: number
}

export default function ProjectDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  // Fetch project and tasks
  const { data: projectData, loading: projectLoading, error: projectError } = useProject(id)
  const { data: tasksData, loading: tasksLoading } = useTasks(id)
  const deleteProject = useDeleteProject()

  // Real-time updates
  const { data: realtimeData, connected } = useRealtimeUpdates('/updates')

  const [refreshKey, setRefreshKey] = useState(0)

  // Trigger refresh when real-time update is received
  useEffect(() => {
    if (realtimeData) {
      setRefreshKey(prev => prev + 1)
    }
  }, [realtimeData])

  const project = projectData as Project

  const handleDelete = async () => {
    if (window.confirm(t('confirmDeleteProject', 'Are you sure you want to delete this project?'))) {
      try {
        await deleteProject.mutate(id)
        router.push('/projects')
      } catch (error) {
        console.error('Failed to delete project:', error)
      }
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
          <ArrowLeft className="h-4 w-4 mr-2" />
          {t('back', 'Back')}
        </Button>
      </div>
    )
  }

  // Process tasks for WBS (simplified as task status distribution)
  const taskStats = Array.isArray(tasksData) ? [
    { name: t('status.todo', 'To Do'), value: tasksData.filter((task: any) => task.status === 'todo').length },
    { name: t('status.inProgress', 'In Progress'), value: tasksData.filter((task: any) => task.status === 'in_progress').length },
    { name: t('status.done', 'Done'), value: tasksData.filter((task: any) => task.status === 'done').length },
  ] : []

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-4">
          <Button onClick={() => router.back()} variant="outline">
            <ArrowLeft className="h-4 w-4 mr-2" />
            {t('back', 'Back')}
          </Button>
          <h1 className="text-3xl font-bold">{project.name}</h1>
          <div className={`w-2 h-2 rounded-full mr-2 ${connected ? 'bg-green-500' : 'bg-red-500'}`}></div>
          <span className="text-sm text-gray-600">
            {connected ? 'Real-time connected' : 'Real-time disconnected'}
          </span>
        </div>
        <div className="flex space-x-2">
          <Link href={`/projects/${id}/edit`}>
            <Button variant="outline">
              <Edit className="h-4 w-4 mr-2" />
              {t('edit', 'Edit')}
            </Button>
          </Link>
          <Button variant="destructive" onClick={handleDelete} disabled={deleteProject.loading}>
            <Trash2 className="h-4 w-4 mr-2" />
            {t('delete', 'Delete')}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        {/* Project Info */}
        <Card className="p-6 lg:col-span-2">
          <h2 className="text-xl font-semibold mb-4">{t('projectDetails', 'Project Details')}</h2>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium text-gray-600">{t('description', 'Description')}</label>
              <p className="mt-1">{project.description || t('noDescription', 'No description provided')}</p>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('status', 'Status')}</label>
                <div className="mt-1">
                  <Badge variant={
                    project.status === 'completed' ? 'default' :
                    project.status === 'active' ? 'secondary' :
                    'outline'
                  }>
                    {project.status}
                  </Badge>
                </div>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('progress', 'Progress')}</label>
                <div className="mt-1 flex items-center space-x-2">
                  <Progress value={project.progress || 0} className="flex-1" />
                  <span className="text-sm">{project.progress || 0}%</span>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="flex items-center space-x-2">
                <Calendar className="h-4 w-4 text-gray-500" />
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('startDate', 'Start Date')}</label>
                  <p className="text-sm">{project.startDate ? new Date(project.startDate).toLocaleDateString() : t('notSet', 'Not set')}</p>
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <Calendar className="h-4 w-4 text-gray-500" />
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('endDate', 'End Date')}</label>
                  <p className="text-sm">{project.endDate ? new Date(project.endDate).toLocaleDateString() : t('notSet', 'Not set')}</p>
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
                <span className="text-sm">{t('totalTasks', 'Total Tasks')}</span>
              </div>
              <span className="font-semibold">{Array.isArray(tasksData) ? tasksData.length : 0}</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Users className="h-5 w-5 text-blue-500" />
                <span className="text-sm">{t('teamMembers', 'Team Members')}</span>
              </div>
              <span className="font-semibold">{project.teamMembers?.length || 0}</span>
            </div>
          </div>
        </Card>
      </div>

      {/* WBS Visualization */}
      <Card className="p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">{t('wbsVisualization', 'WBS Visualization')}</h2>
        {Array.isArray(tasksData) && tasksData.length > 0 ? (
          <WBSTree
            tasks={tasksData.map((task: any) => ({
              ...task,
              level: 0,
              children: []
            }))}
            onTaskUpdate={(taskId, updates) => {
              // Implement task update logic here
              console.log('Update task', taskId, updates)
            }}
            onTaskMove={(taskId, newParentId) => {
              // Implement task move logic here
              console.log('Move task', taskId, newParentId)
            }}
            onTaskAdd={(parentId) => {
              // Implement task add logic here
              console.log('Add task under', parentId)
            }}
            onTaskDelete={(taskId) => {
              // Implement task delete logic here
              console.log('Delete task', taskId)
            }}
            onExport={(format) => {
              // Implement export logic here
              console.log('Export WBS as', format)
            }}
          />
        ) : (
          <div className="flex items-center justify-center h-48 text-gray-500">
            {t('noTasksForWBS', 'No tasks available for WBS visualization')}
          </div>
        )}
      </Card>

      {/* Tasks List */}
      <Card className="p-6">
        <h2 className="text-xl font-semibold mb-4">{t('projectTasks', 'Project Tasks')}</h2>
        {tasksLoading ? (
          <div className="flex justify-center py-4">
            <Loader2 className="h-6 w-6 animate-spin" />
          </div>
        ) : Array.isArray(tasksData) && tasksData.length > 0 ? (
          <div className="space-y-4">
            {tasksData.map((task: any) => (
              <div key={task.id} className="flex items-center justify-between p-4 border rounded-lg">
                <div>
                  <h3 className="font-medium">{task.name}</h3>
                  <p className="text-sm text-gray-600">{task.description}</p>
                  <div className="flex items-center space-x-2 mt-2">
                    <Badge variant={
                      task.priority === 'high' ? 'destructive' :
                      task.priority === 'medium' ? 'default' :
                      'secondary'
                    }>
                      {task.priority}
                    </Badge>
                    <Badge variant="outline">{task.status}</Badge>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm text-gray-500">
                    {task.dueDate ? new Date(task.dueDate).toLocaleDateString() : t('noDueDate', 'No due date')}
                  </p>
                  <Progress value={task.progress || 0} className="w-20 mt-2" />
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            {t('noTasksInProject', 'No tasks in this project')}
          </div>
        )}
      </Card>
    </div>
  )
}
