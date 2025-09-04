'use client'

import React, { useState, useRef, useCallback } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import {
  ChevronRight,
  ChevronDown,
  GripVertical,
  Download,
  Plus,
  Edit,
  Trash2,
  Calendar,
  Users,
  CheckCircle,
  Clock,
  AlertTriangle
} from 'lucide-react'

interface WBSTask {
  id: string
  name: string
  description?: string
  status: 'todo' | 'in_progress' | 'done' | 'blocked'
  priority: 'low' | 'medium' | 'high' | 'critical'
  progress: number
  startDate?: string
  endDate?: string
  duration?: number
  dependencies?: string[]
  children?: WBSTask[]
  level: number
  parentId?: string
}

interface WBSTreeProps {
  tasks: WBSTask[]
  onTaskUpdate: (taskId: string, updates: Partial<WBSTask>) => void
  onTaskMove: (taskId: string, newParentId?: string, newIndex?: number) => void
  onTaskAdd: (parentId?: string) => void
  onTaskDelete: (taskId: string) => void
  onExport: (format: 'json' | 'csv' | 'pdf') => void
}

export default function WBSTree({
  tasks,
  onTaskUpdate,
  onTaskMove,
  onTaskAdd,
  onTaskDelete,
  onExport
}: WBSTreeProps) {
  const { t } = useTranslation('common')
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [draggedTask, setDraggedTask] = useState<WBSTask | null>(null)
  const [dragOverNode, setDragOverNode] = useState<string | null>(null)
  const dragRef = useRef<HTMLDivElement>(null)

  const toggleExpanded = useCallback((taskId: string) => {
    setExpandedNodes(prev => {
      const newSet = new Set(prev)
      if (newSet.has(taskId)) {
        newSet.delete(taskId)
      } else {
        newSet.add(taskId)
      }
      return newSet
    })
  }, [])

  const handleDragStart = useCallback((e: React.DragEvent, task: WBSTask) => {
    setDraggedTask(task)
    e.dataTransfer.effectAllowed = 'move'
    e.dataTransfer.setData('text/plain', task.id)
  }, [])

  const handleDragOver = useCallback((e: React.DragEvent, taskId: string) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    setDragOverNode(taskId)
  }, [])

  const handleDragLeave = useCallback(() => {
    setDragOverNode(null)
  }, [])

  const handleDrop = useCallback((e: React.DragEvent, targetTaskId: string) => {
    e.preventDefault()
    setDragOverNode(null)

    if (!draggedTask || draggedTask.id === targetTaskId) return

    // Prevent dropping on own children
    const isChild = (parentId: string, childId: string): boolean => {
      const findTask = (tasks: WBSTask[], id: string): WBSTask | null => {
        for (const task of tasks) {
          if (task.id === id) return task
          if (task.children) {
            const found = findTask(task.children, id)
            if (found) return found
          }
        }
        return null
      }

      const targetTask = findTask(tasks, targetTaskId)
      if (!targetTask?.children) return false

      for (const child of targetTask.children) {
        if (child.id === childId) return true
        if (isChild(child.id, childId)) return true
      }
      return false
    }

    if (isChild(draggedTask.id, targetTaskId)) return

    onTaskMove(draggedTask.id, targetTaskId)
    setDraggedTask(null)
  }, [draggedTask, tasks, onTaskMove])

  const renderTaskNode = (task: WBSTask, index: number): React.ReactNode => {
    const isExpanded = expandedNodes.has(task.id)
    const hasChildren = task.children && task.children.length > 0
    const isDragOver = dragOverNode === task.id

    const getStatusIcon = (status: string) => {
      switch (status) {
        case 'done': return <CheckCircle className="h-4 w-4 text-green-500" />
        case 'in_progress': return <Clock className="h-4 w-4 text-blue-500" />
        case 'blocked': return <AlertTriangle className="h-4 w-4 text-red-500" />
        default: return <div className="h-4 w-4 rounded-full border-2 border-gray-300" />
      }
    }

    const getPriorityColor = (priority: string) => {
      switch (priority) {
        case 'critical': return 'bg-red-100 text-red-800 border-red-200'
        case 'high': return 'bg-orange-100 text-orange-800 border-orange-200'
        case 'medium': return 'bg-yellow-100 text-yellow-800 border-yellow-200'
        case 'low': return 'bg-green-100 text-green-800 border-green-200'
        default: return 'bg-gray-100 text-gray-800 border-gray-200'
      }
    }

    return (
      <div key={task.id} className="wbs-node">
        <div
          className={`flex items-center p-3 border rounded-lg mb-2 transition-all duration-200 ${
            isDragOver ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-gray-300'
          }`}
          style={{ marginLeft: `${task.level * 24}px` }}
          draggable
          onDragStart={(e) => handleDragStart(e, task)}
          onDragOver={(e) => handleDragOver(e, task.id)}
          onDragLeave={handleDragLeave}
          onDrop={(e) => handleDrop(e, task.id)}
        >
          {/* Drag Handle */}
          <div className="flex items-center mr-2 cursor-move">
            <GripVertical className="h-4 w-4 text-gray-400" />
          </div>

          {/* Expand/Collapse */}
          {hasChildren && (
            <Button
              variant="ghost"
              size="sm"
              className="p-1 mr-2"
              onClick={() => toggleExpanded(task.id)}
            >
              {isExpanded ? (
                <ChevronDown className="h-4 w-4" />
              ) : (
                <ChevronRight className="h-4 w-4" />
              )}
            </Button>
          )}

          {/* Status Icon */}
          <div className="mr-3">
            {getStatusIcon(task.status)}
          </div>

          {/* Task Content */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between">
              <h4 className="font-medium text-sm truncate">{task.name}</h4>
              <div className="flex items-center space-x-2 ml-4">
                <Badge className={`text-xs ${getPriorityColor(task.priority)}`}>
                  {task.priority}
                </Badge>
                <span className="text-xs text-gray-500">{task.progress}%</span>
              </div>
            </div>

            {task.description && (
              <p className="text-xs text-gray-600 mt-1 truncate">{task.description}</p>
            )}

            <div className="flex items-center justify-between mt-2">
              <div className="flex items-center space-x-4 text-xs text-gray-500">
                {task.startDate && (
                  <div className="flex items-center space-x-1">
                    <Calendar className="h-3 w-3" />
                    <span>{new Date(task.startDate).toLocaleDateString()}</span>
                  </div>
                )}
                {task.duration && (
                  <div className="flex items-center space-x-1">
                    <Clock className="h-3 w-3" />
                    <span>{task.duration}d</span>
                  </div>
                )}
              </div>

              <Progress value={task.progress} className="w-16 h-1" />
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center space-x-1 ml-4">
            <Button
              variant="ghost"
              size="sm"
              className="p-1"
              onClick={() => onTaskAdd(task.id)}
            >
              <Plus className="h-3 w-3" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="p-1"
              onClick={() => onTaskUpdate(task.id, {})}
            >
              <Edit className="h-3 w-3" />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="p-1 text-red-500 hover:text-red-700"
              onClick={() => onTaskDelete(task.id)}
            >
              <Trash2 className="h-3 w-3" />
            </Button>
          </div>
        </div>

        {/* Children */}
        {hasChildren && isExpanded && (
          <div className="ml-6">
            {task.children!.map((child, childIndex) => renderTaskNode(child, childIndex))}
          </div>
        )}
      </div>
    )
  }

  const calculateWBSMetrics = () => {
    const calculateMetrics = (tasks: WBSTask[]): {
      totalTasks: number
      completedTasks: number
      totalDuration: number
      criticalPath: number
    } => {
      let totalTasks = 0
      let completedTasks = 0
      let totalDuration = 0
      let criticalPath = 0

      const processTask = (task: WBSTask) => {
        totalTasks++
        if (task.status === 'done') completedTasks++
        if (task.duration) totalDuration += task.duration
        if (task.priority === 'critical' && task.duration) {
          criticalPath = Math.max(criticalPath, task.duration)
        }

        if (task.children) {
          task.children.forEach(processTask)
        }
      }

      tasks.forEach(processTask)
      return { totalTasks, completedTasks, totalDuration, criticalPath }
    }

    return calculateMetrics(tasks)
  }

  const metrics = calculateWBSMetrics()

  return (
    <Card className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold">{t('wbsTree', 'Work Breakdown Structure')}</h2>
          <p className="text-sm text-gray-600 mt-1">
            {t('wbsDescription', 'Organize and manage project tasks hierarchically')}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => onTaskAdd()}
          >
            <Plus className="h-4 w-4 mr-2" />
            {t('addTask', 'Add Task')}
          </Button>

          <div className="flex items-center space-x-1">
            <Button
              variant="outline"
              size="sm"
              onClick={() => onExport('json')}
            >
              <Download className="h-4 w-4 mr-1" />
              JSON
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => onExport('csv')}
            >
              <Download className="h-4 w-4 mr-1" />
              CSV
            </Button>
          </div>
        </div>
      </div>

      {/* WBS Metrics */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-blue-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-blue-600">{metrics.totalTasks}</div>
          <div className="text-sm text-blue-600">{t('totalTasks', 'Total Tasks')}</div>
        </div>
        <div className="bg-green-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-green-600">{metrics.completedTasks}</div>
          <div className="text-sm text-green-600">{t('completedTasks', 'Completed')}</div>
        </div>
        <div className="bg-orange-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-orange-600">{metrics.totalDuration}</div>
          <div className="text-sm text-orange-600">{t('totalDuration', 'Total Duration (days)')}</div>
        </div>
        <div className="bg-red-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-red-600">{metrics.criticalPath}</div>
          <div className="text-sm text-red-600">{t('criticalPath', 'Critical Path (days)')}</div>
        </div>
      </div>

      {/* WBS Tree */}
      <div className="wbs-container">
        {tasks.length > 0 ? (
          tasks.map((task, index) => renderTaskNode(task, index))
        ) : (
          <div className="text-center py-12 text-gray-500">
            <div className="text-lg mb-2">{t('noTasksInWBS', 'No tasks in WBS')}</div>
            <p className="text-sm">{t('startByAddingTask', 'Start by adding your first task')}</p>
            <Button
              className="mt-4"
              onClick={() => onTaskAdd()}
            >
              <Plus className="h-4 w-4 mr-2" />
              {t('addFirstTask', 'Add First Task')}
            </Button>
          </div>
        )}
      </div>

      <style jsx>{`
        .wbs-node {
          position: relative;
        }

        .wbs-node::before {
          content: '';
          position: absolute;
          left: -12px;
          top: 24px;
          width: 12px;
          height: 1px;
          background-color: #e5e7eb;
        }

        .wbs-node:last-child::after {
          content: '';
          position: absolute;
          left: -12px;
          top: 24px;
          width: 1px;
          height: calc(100% - 24px);
          background-color: #e5e7eb;
        }
      `}</style>
    </Card>
  )
}
