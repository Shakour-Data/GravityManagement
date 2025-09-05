'use client'

import React, { useState, useRef, useCallback, useMemo } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import {
  Calendar,
  ZoomIn,
  ZoomOut,
  Download,
  Settings,
  Play,
  Pause,
  RotateCcw,
  ChevronLeft,
  ChevronRight,
  Filter,
  Search,
  MoreHorizontal,
  AlertTriangle,
  CheckCircle,
  Clock,
  Users
} from 'lucide-react'

interface Task {
  id: string
  name: string
  startDate: string
  endDate: string
  duration: number
  progress: number
  priority: 'low' | 'medium' | 'high' | 'critical'
  status: 'todo' | 'in_progress' | 'done' | 'blocked'
  dependencies?: string[]
  assignee?: string
  color?: string
  parentId?: string
  level?: number
}

interface Milestone {
  id: string
  name: string
  date: string
  color?: string
  description?: string
}

interface GanttChartProps {
  tasks: Task[]
  milestones: Milestone[]
  onTaskUpdate: (taskId: string, updates: Partial<Task>) => void
  onTaskClick: (taskId: string) => void
  onMilestoneClick: (milestoneId: string) => void
  onDateRangeChange: (startDate: Date, endDate: Date) => void
  currentDate?: Date
  showWeekends?: boolean
  showDependencies?: boolean
  showProgress?: boolean
}

export default function GanttChart({
  tasks,
  milestones,
  onTaskUpdate,
  onTaskClick,
  onMilestoneClick,
  onDateRangeChange,
  currentDate = new Date(),
  showWeekends = true,
  showDependencies = true,
  showProgress = true
}: GanttChartProps) {
  const { t } = useTranslation('common')
  const [zoom, setZoom] = useState(1) // 0.5 = 6 months, 1 = 3 months, 2 = 1.5 months, 4 = 0.75 months
  const [viewStartDate, setViewStartDate] = useState(new Date(currentDate.getTime() - 30 * 24 * 60 * 60 * 1000))
  const [viewEndDate, setViewEndDate] = useState(new Date(currentDate.getTime() + 60 * 24 * 60 * 60 * 1000))
  const [selectedTask, setSelectedTask] = useState<string | null>(null)
  const [draggedTask, setDraggedTask] = useState<Task | null>(null)
  const [isPlaying, setIsPlaying] = useState(false)
  const [filterStatus, setFilterStatus] = useState<string>('all')
  const [searchTerm, setSearchTerm] = useState('')
  const chartRef = useRef<HTMLDivElement>(null)

  // Calculate chart dimensions and time scale
  const chartWidth = 1200
  const rowHeight = 40
  const headerHeight = 60
  const dayWidth = 30 * zoom

  const totalDays = Math.ceil((viewEndDate.getTime() - viewStartDate.getTime()) / (24 * 60 * 60 * 1000))
  const chartHeight = tasks.length * rowHeight + headerHeight

  // Filter tasks based on search and status
  const filteredTasks = useMemo(() => {
    return tasks.filter(task => {
      const matchesSearch = task.name.toLowerCase().includes(searchTerm.toLowerCase())
      const matchesStatus = filterStatus === 'all' || task.status === filterStatus
      return matchesSearch && matchesStatus
    })
  }, [tasks, searchTerm, filterStatus])

  // Calculate task positions
  const getTaskPosition = useCallback((task: Task) => {
    const taskStart = new Date(task.startDate)
    const taskEnd = new Date(task.endDate)
    const startOffset = (taskStart.getTime() - viewStartDate.getTime()) / (24 * 60 * 60 * 1000)
    const duration = (taskEnd.getTime() - taskStart.getTime()) / (24 * 60 * 60 * 1000)

    return {
      left: Math.max(0, startOffset * dayWidth),
      width: Math.max(20, duration * dayWidth),
      top: (filteredTasks.findIndex(t => t.id === task.id) * rowHeight) + headerHeight
    }
  }, [viewStartDate, dayWidth, filteredTasks, headerHeight])

  // Generate time scale headers
  const generateTimeHeaders = useCallback(() => {
    const headers = []
    const current = new Date(viewStartDate)

    while (current <= viewEndDate) {
      const month = current.toLocaleDateString('en-US', { month: 'short' })
      const year = current.getFullYear()
      const week = Math.ceil((current.getDate() - current.getDay() + 1) / 7)

      headers.push({
        date: new Date(current),
        month: `${month} ${year}`,
        week: `W${week}`,
        day: current.getDate().toString()
      })

      current.setDate(current.getDate() + 1)
    }

    return headers
  }, [viewStartDate, viewEndDate])

  const timeHeaders = generateTimeHeaders()

  // Handle zoom controls
  const handleZoomIn = () => setZoom(prev => Math.min(prev * 1.5, 4))
  const handleZoomOut = () => setZoom(prev => Math.max(prev / 1.5, 0.25))
  const handlePanLeft = () => {
    const newStart = new Date(viewStartDate.getTime() - 7 * 24 * 60 * 60 * 1000)
    setViewStartDate(newStart)
    onDateRangeChange(newStart, viewEndDate)
  }
  const handlePanRight = () => {
    const newEnd = new Date(viewEndDate.getTime() + 7 * 24 * 60 * 60 * 1000)
    setViewEndDate(newEnd)
    onDateRangeChange(viewStartDate, newEnd)
  }

  // Handle task drag and drop
  const handleTaskDragStart = useCallback((e: React.DragEvent, task: Task) => {
    setDraggedTask(task)
    e.dataTransfer.effectAllowed = 'move'
  }, [])

  const handleTaskDrop = useCallback((e: React.DragEvent) => {
    if (!draggedTask || !chartRef.current) return

    const rect = chartRef.current.getBoundingClientRect()
    const x = e.clientX - rect.left
    const daysOffset = Math.round(x / dayWidth)
    const newStartDate = new Date(viewStartDate.getTime() + daysOffset * 24 * 60 * 60 * 1000)
    const newEndDate = new Date(newStartDate.getTime() + draggedTask.duration * 24 * 60 * 60 * 1000)

    onTaskUpdate(draggedTask.id, {
      startDate: newStartDate.toISOString().split('T')[0],
      endDate: newEndDate.toISOString().split('T')[0]
    })

    setDraggedTask(null)
  }, [draggedTask, dayWidth, viewStartDate, onTaskUpdate])

  // Get task color based on status and priority
  const getTaskColor = (task: Task) => {
    if (task.color) return task.color

    switch (task.status) {
      case 'done': return '#10B981'
      case 'in_progress': return '#3B82F6'
      case 'blocked': return '#EF4444'
      case 'todo':
        switch (task.priority) {
          case 'critical': return '#DC2626'
          case 'high': return '#EA580C'
          case 'medium': return '#D97706'
          case 'low': return '#65A30D'
          default: return '#6B7280'
        }
      default: return '#6B7280'
    }
  }

  // Get status icon
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'done': return <CheckCircle className="h-3 w-3" />
      case 'in_progress': return <Play className="h-3 w-3" />
      case 'blocked': return <AlertTriangle className="h-3 w-3" />
      case 'todo': return <Clock className="h-3 w-3" />
      default: return <Clock className="h-3 w-3" />
    }
  }

  // Calculate critical path (simplified)
  const getCriticalTasks = useCallback(() => {
    return tasks.filter(task => task.priority === 'critical' || task.status === 'blocked')
  }, [tasks])

  const criticalTasks = getCriticalTasks()

  return (
    <Card className="p-6">
      {/* Header Controls */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold">{t('ganttChart', 'Gantt Chart')}</h2>
          <p className="text-sm text-gray-600 mt-1">
            {t('ganttChartDescription', 'Visualize project timeline and task dependencies')}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {/* Search */}
          <div className="relative">
            <Search className="h-4 w-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder={t('searchTasks', 'Search tasks...')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9 pr-3 py-2 border rounded-md text-sm w-48"
            />
          </div>

          {/* Status Filter */}
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="px-3 py-2 border rounded-md text-sm"
          >
            <option value="all">{t('allStatuses', 'All Statuses')}</option>
            <option value="todo">{t('todo', 'To Do')}</option>
            <option value="in_progress">{t('inProgress', 'In Progress')}</option>
            <option value="done">{t('done', 'Done')}</option>
            <option value="blocked">{t('blocked', 'Blocked')}</option>
          </select>

          {/* Zoom Controls */}
          <Button variant="outline" size="sm" onClick={handleZoomOut} aria-label="Zoom Out">
            <ZoomOut className="h-4 w-4" />
          </Button>
          <span className="text-sm text-gray-600 min-w-[60px] text-center">
            {Math.round(zoom * 100)}%
          </span>
          <Button variant="outline" size="sm" onClick={handleZoomIn} aria-label="Zoom In">
            <ZoomIn className="h-4 w-4" />
          </Button>

          {/* Pan Controls */}
          <Button variant="outline" size="sm" onClick={handlePanLeft}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <Button variant="outline" size="sm" onClick={handlePanRight}>
            <ChevronRight className="h-4 w-4" />
          </Button>

          {/* Export */}
          <Button variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            {t('export', 'Export')}
          </Button>
        </div>
      </div>

      {/* Chart Container */}
      <div className="border rounded-lg overflow-hidden bg-white">
        <div
          ref={chartRef}
          className="relative"
          style={{ width: chartWidth, height: chartHeight }}
          onDrop={handleTaskDrop}
          onDragOver={(e) => e.preventDefault()}
        >
          {/* Time Scale Header */}
          <div className="absolute top-0 left-0 right-0 h-16 bg-gray-50 border-b flex">
            <div className="w-64 border-r bg-gray-100 flex items-center px-4">
              <span className="font-medium text-sm">{t('tasks', 'Tasks')}</span>
            </div>
            <div className="flex-1 overflow-x-auto">
              <div className="flex" style={{ width: totalDays * dayWidth }}>
                {timeHeaders.map((header, index) => (
                  <div
                    key={index}
                    className="border-r border-gray-200 text-center"
                    style={{ width: dayWidth, minWidth: dayWidth }}
                  >
                    <div className="text-xs text-gray-500 py-1">
                      {header.month}
                    </div>
                    <div className="text-xs font-medium">
                      {header.day}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Task Rows */}
          {filteredTasks.map((task, index) => {
            const position = getTaskPosition(task)
            const isCritical = criticalTasks.some(ct => ct.id === task.id)
            const isSelected = selectedTask === task.id

            return (
              <div
                key={task.id}
                className="absolute left-0 right-0 border-b border-gray-100"
                style={{
                  top: headerHeight + index * rowHeight,
                  height: rowHeight
                }}
              >
                {/* Task Name Column */}
                <div className="absolute left-0 w-64 h-full border-r bg-white flex items-center px-4">
                  <div className="flex items-center space-x-2 flex-1">
                    {getStatusIcon(task.status)}
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-sm truncate" title={task.name}>
                        {task.name}
                      </div>
                      <div className="flex items-center space-x-2 text-xs text-gray-500">
                        {task.assignee && (
                          <div className="flex items-center space-x-1">
                            <Users className="h-3 w-3" />
                            <span>{task.assignee}</span>
                          </div>
                        )}
                        <Badge
                          className={`text-xs ${
                            task.priority === 'critical' ? 'bg-red-100 text-red-800' :
                            task.priority === 'high' ? 'bg-orange-100 text-orange-800' :
                            task.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}
                        >
                          {task.priority}
                        </Badge>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Task Bar */}
                <div
                  className={`absolute cursor-pointer transition-all duration-200 ${
                    isSelected ? 'ring-2 ring-blue-500' : ''
                  } ${isCritical ? 'ring-2 ring-red-500' : ''}`}
                  style={{
                    left: 256 + position.left,
                    top: 8,
                    width: position.width,
                    height: 24
                  }}
                  draggable
                  onDragStart={(e) => handleTaskDragStart(e, task)}
                  onClick={() => {
                    setSelectedTask(task.id)
                    onTaskClick(task.id)
                  }}
                >
                  <div
                    className="h-full rounded flex items-center px-2 text-white text-xs font-medium"
                    style={{ backgroundColor: getTaskColor(task) }}
                  >
                    <span className="truncate">{task.name}</span>
                    {showProgress && (
                      <div className="ml-auto flex items-center space-x-1">
                        <span>{task.progress}%</span>
                        <div className="w-8 h-1 bg-white bg-opacity-30 rounded">
                          <div
                            className="h-full bg-white rounded"
                            style={{ width: `${task.progress}%` }}
                            data-testid="task-progress-bar"
                          />
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                {/* Progress Line */}
                {showProgress && task.progress > 0 && (
                  <div
                    className="absolute top-0 h-0.5 bg-green-500"
                    style={{
                      left: 256 + position.left,
                      width: position.width * (task.progress / 100),
                      top: 16
                    }}
                  />
                )}
              </div>
            )
          })}

          {/* Milestones */}
          {milestones.map(milestone => {
            const milestoneDate = new Date(milestone.date)
            const offset = (milestoneDate.getTime() - viewStartDate.getTime()) / (24 * 60 * 60 * 1000)
            const left = 256 + offset * dayWidth

            return (
              <div
                key={milestone.id}
                className="absolute cursor-pointer"
                style={{
                  left: left - 8,
                  top: headerHeight - 20,
                  width: 16,
                  height: 16
                }}
                onClick={() => onMilestoneClick(milestone.id)}
              >
                <div
                  className="w-full h-full transform rotate-45 border-2 border-white shadow-lg"
                  style={{ backgroundColor: milestone.color || '#3B82F6' }}
                />
                <div className="absolute -bottom-6 left-1/2 transform -translate-x-1/2 text-xs font-medium text-gray-700 whitespace-nowrap">
                  {milestone.name}
                </div>
              </div>
            )
          })}

          {/* Current Date Line */}
          <div
            className="absolute top-0 bottom-0 w-0.5 bg-red-500 z-10"
            style={{
              left: 256 + ((currentDate.getTime() - viewStartDate.getTime()) / (24 * 60 * 60 * 1000)) * dayWidth
            }}
          >
            <div className="absolute -top-2 -left-2 w-4 h-4 bg-red-500 rounded-full border-2 border-white" />
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="mt-4 flex flex-wrap items-center gap-4 text-sm">
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-red-500 rounded-full border-2 border-white"></div>
          <span>{t('today', 'Today')}</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-3 bg-blue-500 rounded"></div>
          <span>{t('inProgress', 'In Progress')}</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-3 bg-green-500 rounded"></div>
          <span>{t('completed', 'Completed')}</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-3 bg-red-500 rounded"></div>
          <span>{t('blocked', 'Blocked')}</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-3 bg-gray-500 rounded border-2 border-red-500"></div>
          <span>{t('criticalPath', 'Critical Path')}</span>
        </div>
      </div>

      {/* Task Details Panel */}
      {selectedTask && (
        <Card className="mt-4 p-4">
          <h3 className="font-semibold mb-2">{t('taskDetails', 'Task Details')}</h3>
          {(() => {
            const task = tasks.find(t => t.id === selectedTask)
            if (!task) return null

            return (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('status', 'Status')}</label>
                  <div className="flex items-center space-x-2 mt-1">
                    {getStatusIcon(task.status)}
                    <Badge className={`text-xs ${
                      task.status === 'done' ? 'bg-green-100 text-green-800' :
                      task.status === 'in_progress' ? 'bg-blue-100 text-blue-800' :
                      task.status === 'blocked' ? 'bg-red-100 text-red-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {task.status}
                    </Badge>
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('progress', 'Progress')}</label>
                  <div className="mt-1">
                    <Progress value={task.progress} className="h-2" />
                    <span className="text-xs text-gray-600">{task.progress}%</span>
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('startDate', 'Start Date')}</label>
                  <div className="text-sm mt-1">{new Date(task.startDate).toLocaleDateString()}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('endDate', 'End Date')}</label>
                  <div className="text-sm mt-1">{new Date(task.endDate).toLocaleDateString()}</div>
                </div>
              </div>
            )
          })()}
        </Card>
      )}
    </Card>
  )
}
