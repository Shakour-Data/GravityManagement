'use client'

import React, { useState, useCallback } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useTasks, useUpdateTask } from '@/lib/hooks'
import { Loader2, Plus, ArrowRight, ArrowLeft, Trash2 } from 'lucide-react'
import Link from 'next/link'
import { useMemo } from 'react'

interface TaskDependency {
  task_id: string
  dependency_type: string
}

interface Task {
  id: string
  title: string
  description?: string
  status: 'todo' | 'in_progress' | 'done' | 'blocked'
  priority: number
  dependencies?: TaskDependency[]
}

interface TaskDependenciesProps {
  taskId: string
}

export default function TaskDependencies({ taskId }: TaskDependenciesProps) {
  const { t } = useTranslation('common')
  const { data: tasksData, loading, error } = useTasks()
  const [showAddDependency, setShowAddDependency] = useState(false)

  const tasks = Array.isArray(tasksData) ? tasksData : []

  const currentTask = tasks.find((task: Task) => task.id === taskId)

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

  if (!currentTask) {
    return (
      <div className="text-center py-8 text-gray-500">
        {t('taskNotFound', 'Task not found')}
      </div>
    )
  }

  const dependencies = tasks.filter((task: Task) =>
    currentTask.dependencies?.some((dep: TaskDependency) => dep.task_id === task.id)
  )

  const dependents = tasks.filter((task: Task) =>
    task.dependencies?.some((dep: TaskDependency) => dep.task_id === taskId)
  )

  const availableTasks = tasks.filter((task: Task) =>
    task.id !== taskId && !currentTask.dependencies?.some((dep: TaskDependency) => dep.task_id === task.id)
  )

  const updateTaskMutation = useUpdateTask(taskId)

  // Simple graph data
  const graphData = useMemo(() => {
    const allTasks = [currentTask, ...dependencies, ...dependents]
    const uniqueTasks = allTasks.filter((task, index, self) => self.findIndex(t => t.id === task.id) === index)

    return uniqueTasks.map((task, index) => ({
      id: task.id,
      title: task.title,
      x: (index % 3) * 150 + 50,
      y: Math.floor(index / 3) * 100 + 50,
      isCurrent: task.id === taskId,
      status: task.status
    }))
  }, [currentTask, dependencies, dependents, taskId])

  const graphEdges = useMemo(() => {
    const edges: Array<{from: string, to: string}> = []
    dependencies.forEach(dep => {
      edges.push({from: dep.id, to: taskId})
    })
    dependents.forEach(dep => {
      edges.push({from: taskId, to: dep.id})
    })
    return edges
  }, [dependencies, dependents, taskId])

  const addDependency = async (depTaskId: string) => {
    if (!currentTask) return
    const newDependencies = currentTask.dependencies ? [...currentTask.dependencies] : []
    if (!newDependencies.find((d: TaskDependency) => d.task_id === depTaskId)) {
      newDependencies.push({ task_id: depTaskId, dependency_type: 'finish_to_start' })
      try {
        await updateTaskMutation.mutate({ dependencies: newDependencies })
      } catch (error) {
        console.error('Failed to add dependency', error)
      }
    }
  }

  const removeDependency = async (depTaskId: string) => {
    if (!currentTask) return
    const newDependencies = currentTask.dependencies?.filter((d: TaskDependency) => d.task_id !== depTaskId) || []
    try {
      await updateTaskMutation.mutate({ dependencies: newDependencies })
    } catch (error) {
      console.error('Failed to remove dependency', error)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold">{t('taskDependencies', 'Task Dependencies')}</h3>
        <Button
          variant="outline"
          size="sm"
          onClick={() => setShowAddDependency(!showAddDependency)}
        >
          <Plus className="h-4 w-4 mr-2" />
          {t('addDependency', 'Add Dependency')}
        </Button>
      </div>

      {/* Dependency Graph Visualization */}
      <Card className="p-4" style={{ height: 400 }}>
        <svg width="100%" height="100%" viewBox="0 0 500 300">
          {graphEdges.map((edge, index) => {
            const fromNode = graphData.find(n => n.id === edge.from)
            const toNode = graphData.find(n => n.id === edge.to)
            if (!fromNode || !toNode) return null
            return (
              <line
                key={index}
                x1={fromNode.x + 50}
                y1={fromNode.y + 25}
                x2={toNode.x + 50}
                y2={toNode.y + 25}
                stroke="#3b82f6"
                strokeWidth="2"
                markerEnd="url(#arrowhead)"
              />
            )
          })}
          <defs>
            <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
              <polygon points="0 0, 10 3.5, 0 7" fill="#3b82f6" />
            </marker>
          </defs>
          {graphData.map((node) => (
            <g key={node.id}>
              <rect
                x={node.x}
                y={node.y}
                width="100"
                height="50"
                fill={node.isCurrent ? '#dbeafe' : '#f9fafb'}
                stroke={node.isCurrent ? '#3b82f6' : '#d1d5db'}
                strokeWidth={node.isCurrent ? '3' : '1'}
                rx="5"
              />
              <text
                x={node.x + 50}
                y={node.y + 30}
                textAnchor="middle"
                fontSize="12"
                fill="#374151"
              >
                {node.title.length > 10 ? node.title.substring(0, 10) + '...' : node.title}
              </text>
            </g>
          ))}
        </svg>
      </Card>

      {/* Dependencies (tasks this task depends on) */}
      <Card className="p-4">
        <h4 className="font-medium mb-3 flex items-center">
          <ArrowLeft className="h-4 w-4 mr-2" />
          {t('dependsOn', 'Depends On')} ({dependencies.length})
        </h4>
        {dependencies.length > 0 ? (
          <div className="space-y-2">
            {dependencies.map((task: Task) => (
              <div key={task.id} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div className="flex items-center space-x-2">
                  <Badge
                    variant={
                      task.status === 'done' ? 'default' :
                      task.status === 'in_progress' ? 'secondary' :
                      'outline'
                    }
                  >
                    {task.status}
                  </Badge>
                  <Link href={`/tasks/${task.id}`} className="text-blue-600 hover:underline">
                    {task.title}
                  </Link>
                </div>
                <Button variant="outline" size="sm" onClick={() => removeDependency(task.id)}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-500 text-sm">{t('noDependencies', 'No dependencies')}</p>
        )}
      </Card>

      {/* Dependents (tasks that depend on this task) */}
      <Card className="p-4">
        <h4 className="font-medium mb-3 flex items-center">
          <ArrowRight className="h-4 w-4 mr-2" />
          {t('dependents', 'Dependents')} ({dependents.length})
        </h4>
        {dependents.length > 0 ? (
          <div className="space-y-2">
            {dependents.map((task: Task) => (
              <div key={task.id} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div className="flex items-center space-x-2">
                  <Badge
                    variant={
                      task.status === 'done' ? 'default' :
                      task.status === 'in_progress' ? 'secondary' :
                      'outline'
                    }
                  >
                    {task.status}
                  </Badge>
                  <Link href={`/tasks/${task.id}`} className="text-blue-600 hover:underline">
                    {task.title}
                  </Link>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-500 text-sm">{t('noDependents', 'No dependents')}</p>
        )}
      </Card>

      {/* Add Dependency Form */}
      {showAddDependency && (
        <Card className="p-4">
          <h4 className="font-medium mb-3">{t('addNewDependency', 'Add New Dependency')}</h4>
          <div className="space-y-2">
            {availableTasks.map((task: Task) => (
              <div key={task.id} className="flex items-center justify-between p-2 border rounded">
                <div className="flex items-center space-x-2">
                  <Badge
                    variant={
                      task.status === 'done' ? 'default' :
                      task.status === 'in_progress' ? 'secondary' :
                      'outline'
                    }
                  >
                    {task.status}
                  </Badge>
                  <span>{task.title}</span>
                </div>
                <Button variant="outline" size="sm" onClick={() => addDependency(task.id)}>
                  {t('add', 'Add')}
                </Button>
              </div>
            ))}
          </div>
          {availableTasks.length === 0 && (
            <p className="text-gray-500 text-sm">{t('noAvailableTasks', 'No available tasks')}</p>
          )}
        </Card>
      )}
    </div>
  )
}
