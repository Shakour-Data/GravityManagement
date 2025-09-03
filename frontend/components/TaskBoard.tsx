'use client'

import React, { useState } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { useTasks, useUpdateTask, useRealtimeUpdates } from '@/lib/hooks'
import { Loader2, Plus } from 'lucide-react'
import Link from 'next/link'

interface Task {
  id: string
  name: string
  description: string
  status: 'todo' | 'in_progress' | 'done'
  priority: 'low' | 'medium' | 'high'
  progress: number
  dueDate?: string
}

export default function TaskBoard() {
  const { t } = useTranslation('common')
  const { data: tasksData, loading, error } = useTasks()
  const updateTask = useUpdateTask('')
  const { data: realtimeData, connected } = useRealtimeUpdates('/updates')

  const [draggedTask, setDraggedTask] = useState<Task | null>(null)
  const [refreshKey, setRefreshKey] = useState(0)

  const tasks = Array.isArray(tasksData) ? tasksData : []

  // Trigger refresh when real-time update is received
  React.useEffect(() => {
    if (realtimeData) {
      setRefreshKey(prev => prev + 1)
    }
  }, [realtimeData])

  const columns = [
    { id: 'todo', title: t('todo', 'To Do'), color: 'bg-gray-100' },
    { id: 'in_progress', title: t('inProgress', 'In Progress'), color: 'bg-blue-100' },
    { id: 'done', title: t('done', 'Done'), color: 'bg-green-100' },
  ]

  const handleDragStart = (task: Task) => {
    setDraggedTask(task)
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
  }

  const handleDrop = async (e: React.DragEvent, newStatus: string) => {
    e.preventDefault()
    if (!draggedTask || draggedTask.status === newStatus) return

    try {
      await updateTask.mutate({ ...draggedTask, status: newStatus })
      setDraggedTask(null)
    } catch (error) {
      console.error('Failed to update task status:', error)
    }
  }

  const getTasksByStatus = (status: string) => {
    return tasks.filter((task: Task) => task.status === status)
  }

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (error) {
    return (
      <div className="text-center py-8 text-red-500">
        {t('failedToLoadTasks', 'Failed to load tasks')}: {error}
      </div>
    )
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold">{t('taskBoard', 'Task Board')}</h1>
          <div className="flex items-center mt-2">
            <div className={`w-2 h-2 rounded-full mr-2 ${connected ? 'bg-green-500' : 'bg-red-500'}`}></div>
            <span className="text-sm text-gray-600">
              {connected ? 'Real-time connected' : 'Real-time disconnected'}
            </span>
          </div>
        </div>
        <Link href="/tasks/create">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            {t('createTask', 'Create Task')}
          </Button>
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {columns.map((column) => (
          <div
            key={column.id}
            className={`${column.color} p-4 rounded-lg min-h-96`}
            onDragOver={handleDragOver}
            onDrop={(e) => handleDrop(e, column.id)}
          >
            <h2 className="text-lg font-semibold mb-4">{column.title}</h2>
            <div className="space-y-3">
              {getTasksByStatus(column.id).map((task: Task) => (
                <Card
                  key={task.id}
                  className="p-4 cursor-move"
                  draggable
                  onDragStart={() => handleDragStart(task)}
                >
                  <h3 className="font-medium mb-2">{task.name}</h3>
                  <p className="text-sm text-gray-600 mb-2 line-clamp-2">{task.description}</p>
                  <div className="flex items-center justify-between mb-2">
                    <Badge
                      variant={
                        task.priority === 'high'
                          ? 'destructive'
                          : task.priority === 'medium'
                            ? 'default'
                            : 'secondary'
                      }
                    >
                      {task.priority}
                    </Badge>
                    <span className="text-sm text-gray-500">{task.progress}%</span>
                  </div>
                  <Progress value={task.progress} className="mb-2" />
                  {task.dueDate && (
                    <p className="text-xs text-gray-500">
                      {t('due', 'Due')}: {new Date(task.dueDate).toLocaleDateString()}
                    </p>
                  )}
                </Card>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
