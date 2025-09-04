'use client'

import React, { useState, useRef, useCallback } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import {
  Users,
  Calendar,
  AlertTriangle,
  CheckCircle,
  Clock,
  Plus,
  Minus,
  RotateCcw,
  Download,
  Upload,
  Settings
} from 'lucide-react'

interface Resource {
  id: string
  name: string
  type: 'human' | 'material' | 'financial'
  capacity: number
  available: number
  cost: number
  skills?: string[]
}

interface Task {
  id: string
  name: string
  startDate: string
  endDate: string
  duration: number
  priority: 'low' | 'medium' | 'high' | 'critical'
  status: 'todo' | 'in_progress' | 'done' | 'blocked'
}

interface Allocation {
  resourceId: string
  taskId: string
  allocation: number // percentage or hours
  startDate: string
  endDate: string
}

interface ResourceAllocationMatrixProps {
  resources: Resource[]
  tasks: Task[]
  allocations: Allocation[]
  onAllocationUpdate: (resourceId: string, taskId: string, allocation: number) => void
  onAllocationAdd: (resourceId: string, taskId: string) => void
  onAllocationRemove: (resourceId: string, taskId: string) => void
  onExport: (format: 'csv' | 'excel') => void
  onImport: (data: Allocation[]) => void
}

export default function ResourceAllocationMatrix({
  resources,
  tasks,
  allocations,
  onAllocationUpdate,
  onAllocationAdd,
  onAllocationRemove,
  onExport,
  onImport
}: ResourceAllocationMatrixProps) {
  const { t } = useTranslation('common')
  const [selectedResource, setSelectedResource] = useState<string | null>(null)
  const [selectedTask, setSelectedTask] = useState<string | null>(null)
  const [draggedResource, setDraggedResource] = useState<Resource | null>(null)
  const [draggedTask, setDraggedTask] = useState<Task | null>(null)
  const [showConflicts, setShowConflicts] = useState(false)

  const getAllocation = useCallback((resourceId: string, taskId: string): number => {
    const allocation = allocations.find(a => a.resourceId === resourceId && a.taskId === taskId)
    return allocation?.allocation || 0
  }, [allocations])

  const getResourceUtilization = useCallback((resourceId: string): number => {
    const resourceAllocations = allocations.filter(a => a.resourceId === resourceId)
    const totalAllocation = resourceAllocations.reduce((sum, a) => sum + a.allocation, 0)
    const resource = resources.find(r => r.id === resourceId)
    return resource ? (totalAllocation / resource.capacity) * 100 : 0
  }, [allocations, resources])

  const getTaskUtilization = useCallback((taskId: string): number => {
    const taskAllocations = allocations.filter(a => a.taskId === taskId)
    return taskAllocations.reduce((sum, a) => sum + a.allocation, 0)
  }, [allocations])

  const detectConflicts = useCallback((): Array<{
    resourceId: string
    taskId: string
    type: 'overallocation' | 'skill_mismatch' | 'date_conflict'
    severity: 'warning' | 'error'
  }> => {
    const conflictList: Array<{
      resourceId: string
      taskId: string
      type: 'overallocation' | 'skill_mismatch' | 'date_conflict'
      severity: 'warning' | 'error'
    }> = []

    for (const resource of resources) {
      const utilization = getResourceUtilization(resource.id)
      if (utilization > 100) {
        const resourceAllocations = allocations.filter(a => a.resourceId === resource.id)
        for (const allocation of resourceAllocations) {
          conflictList.push({
            resourceId: resource.id,
            taskId: allocation.taskId,
            type: 'overallocation',
            severity: 'error'
          })
        }
      } else if (utilization > 80) {
        const resourceAllocations = allocations.filter(a => a.resourceId === resource.id)
        for (const allocation of resourceAllocations) {
          conflictList.push({
            resourceId: resource.id,
            taskId: allocation.taskId,
            type: 'overallocation',
            severity: 'warning'
          })
        }
      }
    }

    return conflictList
  }, [resources, allocations, getResourceUtilization])

  const conflicts = detectConflicts()

  const getResourceTypeIcon = (type: string) => {
    switch (type) {
      case 'human': return <Users className="h-4 w-4" />
      case 'material': return <Settings className="h-4 w-4" />
      case 'financial': return <Upload className="h-4 w-4" />
      default: return <Users className="h-4 w-4" />
    }
  }

  const getResourceTypeColor = (type: string) => {
    switch (type) {
      case 'human': return 'bg-blue-100 text-blue-800'
      case 'material': return 'bg-green-100 text-green-800'
      case 'financial': return 'bg-yellow-100 text-yellow-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'critical': return 'bg-red-100 text-red-800'
      case 'high': return 'bg-orange-100 text-orange-800'
      case 'medium': return 'bg-yellow-100 text-yellow-800'
      case 'low': return 'bg-green-100 text-green-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'done': return 'bg-green-100 text-green-800'
      case 'in_progress': return 'bg-blue-100 text-blue-800'
      case 'blocked': return 'bg-red-100 text-red-800'
      case 'todo': return 'bg-gray-100 text-gray-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getAllocationColor = (allocation: number, capacity: number) => {
    const percentage = (allocation / capacity) * 100
    if (percentage > 100) return 'bg-red-500'
    if (percentage > 80) return 'bg-orange-500'
    if (percentage > 50) return 'bg-yellow-500'
    if (percentage > 0) return 'bg-green-500'
    return 'bg-gray-200'
  }

  const handleDragStart = useCallback((e: React.DragEvent, item: Resource | Task, type: 'resource' | 'task') => {
    if (type === 'resource') {
      setDraggedResource(item as Resource)
    } else {
      setDraggedTask(item as Task)
    }
    e.dataTransfer.effectAllowed = 'copy'
  }, [])

  const handleDrop = useCallback((e: React.DragEvent, targetResourceId: string, targetTaskId: string) => {
    e.preventDefault()
    if (draggedResource && draggedTask) {
      onAllocationAdd(draggedResource.id, draggedTask.id)
    }
    setDraggedResource(null)
    setDraggedTask(null)
  }, [draggedResource, draggedTask, onAllocationAdd])

  const handleAllocationChange = useCallback((resourceId: string, taskId: string, newAllocation: number) => {
    if (newAllocation <= 0) {
      onAllocationRemove(resourceId, taskId)
    } else {
      onAllocationUpdate(resourceId, taskId, newAllocation)
    }
  }, [onAllocationUpdate, onAllocationRemove])

  return (
    <Card className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold">{t('resourceAllocationMatrix', 'Resource Allocation Matrix')}</h2>
          <p className="text-sm text-gray-600 mt-1">
            {t('resourceAllocationDescription', 'Manage resource assignments across project tasks')}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowConflicts(!showConflicts)}
            className={conflicts.length > 0 ? 'border-red-500 text-red-600' : ''}
          >
            <AlertTriangle className="h-4 w-4 mr-2" />
            {conflicts.length} {t('conflicts', 'Conflicts')}
          </Button>

          <Button
            variant="outline"
            size="sm"
            onClick={() => onExport('csv')}
          >
            <Download className="h-4 w-4 mr-2" />
            {t('export', 'Export')}
          </Button>

          <Button
            variant="outline"
            size="sm"
            onClick={() => onImport([])}
          >
            <Upload className="h-4 w-4 mr-2" />
            {t('import', 'Import')}
          </Button>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-blue-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-blue-600">{resources.length}</div>
          <div className="text-sm text-blue-600">{t('totalResources', 'Total Resources')}</div>
        </div>
        <div className="bg-green-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-green-600">{tasks.length}</div>
          <div className="text-sm text-green-600">{t('totalTasks', 'Total Tasks')}</div>
        </div>
        <div className="bg-orange-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-orange-600">{allocations.length}</div>
          <div className="text-sm text-orange-600">{t('totalAllocations', 'Total Allocations')}</div>
        </div>
        <div className="bg-red-50 p-3 rounded-lg">
          <div className="text-2xl font-bold text-red-600">{conflicts.filter(c => c.severity === 'error').length}</div>
          <div className="text-sm text-red-600">{t('criticalConflicts', 'Critical Conflicts')}</div>
        </div>
      </div>

      {/* Allocation Matrix */}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr>
              <th className="p-3 text-left font-semibold border-b bg-gray-50">
                {t('resources', 'Resources')}
              </th>
              {tasks.map(task => (
                <th
                  key={task.id}
                  className="p-3 text-center font-semibold border-b bg-gray-50 min-w-[120px]"
                  draggable
                  onDragStart={(e) => handleDragStart(e, task, 'task')}
                >
                  <div className="space-y-1">
                    <div className="font-medium text-sm truncate" title={task.name}>
                      {task.name}
                    </div>
                    <Badge className={`text-xs ${getPriorityColor(task.priority)}`}>
                      {task.priority}
                    </Badge>
                    <div className="text-xs text-gray-500">
                      {new Date(task.startDate).toLocaleDateString()}
                    </div>
                  </div>
                </th>
              ))}
              <th className="p-3 text-center font-semibold border-b bg-gray-50">
                {t('utilization', 'Utilization')}
              </th>
            </tr>
          </thead>
          <tbody>
            {resources.map(resource => (
              <tr key={resource.id} className="border-b hover:bg-gray-50">
                <td className="p-3 border-r bg-gray-50">
                  <div
                    className="flex items-center space-x-2 cursor-move"
                    draggable
                    onDragStart={(e) => handleDragStart(e, resource, 'resource')}
                  >
                    {getResourceTypeIcon(resource.type)}
                    <div>
                      <div className="font-medium text-sm">{resource.name}</div>
                      <Badge className={`text-xs ${getResourceTypeColor(resource.type)}`}>
                        {resource.type}
                      </Badge>
                      <div className="text-xs text-gray-500 mt-1">
                        {t('capacity', 'Capacity')}: {resource.capacity}
                      </div>
                    </div>
                  </div>
                </td>

                {tasks.map(task => {
                  const allocation = getAllocation(resource.id, task.id)
                  const hasConflict = conflicts.some(c =>
                    c.resourceId === resource.id && c.taskId === task.id
                  )
                  const conflict = conflicts.find(c =>
                    c.resourceId === resource.id && c.taskId === task.id
                  )

                  return (
                    <td
                      key={`${resource.id}-${task.id}`}
                      className={`p-2 text-center border-r relative ${
                        hasConflict ? 'bg-red-50' : ''
                      }`}
                      onDrop={(e) => handleDrop(e, resource.id, task.id)}
                      onDragOver={(e) => e.preventDefault()}
                    >
                      {allocation > 0 ? (
                        <div className="space-y-2">
                          <div className="flex items-center justify-center space-x-1">
                            <Button
                              variant="ghost"
                              size="sm"
                              className="p-1 h-6 w-6"
                              onClick={() => handleAllocationChange(resource.id, task.id, allocation - 10)}
                            >
                              <Minus className="h-3 w-3" />
                            </Button>
                            <span className="text-sm font-medium min-w-[40px]">
                              {allocation}%
                            </span>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="p-1 h-6 w-6"
                              onClick={() => handleAllocationChange(resource.id, task.id, allocation + 10)}
                            >
                              <Plus className="h-3 w-3" />
                            </Button>
                          </div>
                          <div className="w-full bg-gray-200 rounded-full h-2">
                            <div
                              className={`h-2 rounded-full ${getAllocationColor(allocation, resource.capacity)}`}
                              style={{ width: `${Math.min((allocation / resource.capacity) * 100, 100)}%` }}
                            />
                          </div>
                          {hasConflict && (
                            <div className="absolute top-1 right-1">
                              <AlertTriangle className={`h-3 w-3 ${
                                conflict?.severity === 'error' ? 'text-red-500' : 'text-orange-500'
                              }`} />
                            </div>
                          )}
                        </div>
                      ) : (
                        <div
                          className="w-full h-12 border-2 border-dashed border-gray-300 rounded flex items-center justify-center cursor-pointer hover:border-gray-400 transition-colors"
                          onClick={() => onAllocationAdd(resource.id, task.id)}
                        >
                          <Plus className="h-4 w-4 text-gray-400" />
                        </div>
                      )}
                    </td>
                  )
                })}

                <td className="p-3 text-center">
                  <div className="space-y-2">
                    <div className="text-sm font-medium">
                      {Math.round(getResourceUtilization(resource.id))}%
                    </div>
                    <Progress
                      value={getResourceUtilization(resource.id)}
                      className="w-16 h-2"
                    />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Task Utilization Summary */}
      <div className="mt-6">
        <h3 className="text-lg font-semibold mb-4">{t('taskUtilization', 'Task Utilization')}</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {tasks.map(task => (
            <Card key={task.id} className="p-4">
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-medium text-sm">{task.name}</h4>
                <Badge className={`text-xs ${getStatusColor(task.status)}`}>
                  {task.status}
                </Badge>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span>{t('allocatedResources', 'Allocated Resources')}</span>
                  <span>{getTaskUtilization(task.id)}%</span>
                </div>
                <Progress value={getTaskUtilization(task.id)} className="h-2" />
                <div className="text-xs text-gray-500">
                  {new Date(task.startDate).toLocaleDateString()} - {new Date(task.endDate).toLocaleDateString()}
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>

      {/* Conflicts Panel */}
      {showConflicts && conflicts.length > 0 && (
        <Card className="mt-6 p-4 bg-red-50 border-red-200">
          <h3 className="text-lg font-semibold text-red-800 mb-4">
            {t('resourceConflicts', 'Resource Conflicts')}
          </h3>
          <div className="space-y-2">
            {conflicts.map((conflict, index) => {
              const resource = resources.find(r => r.id === conflict.resourceId)
              const task = tasks.find(t => t.id === conflict.taskId)

              return (
                <div key={index} className="flex items-center justify-between p-3 bg-white rounded border">
                  <div className="flex items-center space-x-3">
                    <AlertTriangle className={`h-5 w-5 ${
                      conflict.severity === 'error' ? 'text-red-500' : 'text-orange-500'
                    }`} />
                    <div>
                      <div className="font-medium text-sm">
                        {resource?.name} → {task?.name}
                      </div>
                      <div className="text-xs text-gray-600">
                        {conflict.type === 'overallocation' ? t('overallocation', 'Overallocation') : t('conflict', 'Conflict')}
                      </div>
                    </div>
                  </div>
                  <Badge variant={conflict.severity === 'error' ? 'destructive' : 'secondary'}>
                    {conflict.severity}
                  </Badge>
                </div>
              )
            })}
          </div>
        </Card>
      )}
    </Card>
  )
}
