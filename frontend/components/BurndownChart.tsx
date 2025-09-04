'use client'

import React, { useState, useRef, useCallback, useMemo } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import {
  TrendingDown,
  TrendingUp,
  Target,
  Calendar,
  Users,
  CheckCircle,
  Clock,
  AlertTriangle,
  Download,
  Settings,
  RefreshCw,
  BarChart3,
  LineChart
} from 'lucide-react'

interface SprintData {
  id: string
  name: string
  startDate: string
  endDate: string
  totalStoryPoints: number
  completedStoryPoints: number
  status: 'active' | 'completed' | 'cancelled'
}

interface BurndownPoint {
  date: string
  ideal: number
  actual: number
  completed: number
  remaining: number
}

interface BurndownChartProps {
  sprint: SprintData
  burndownData: BurndownPoint[]
  onSprintUpdate: (sprintId: string, updates: Partial<SprintData>) => void
  onRefresh: () => void
  showIdealLine?: boolean
  showTrendLine?: boolean
  showVelocity?: boolean
}

export default function BurndownChart({
  sprint,
  burndownData,
  onSprintUpdate,
  onRefresh,
  showIdealLine = true,
  showTrendLine = true,
  showVelocity = true
}: BurndownChartProps) {
  const { t } = useTranslation('common')
  const [selectedPoint, setSelectedPoint] = useState<BurndownPoint | null>(null)
  const [viewMode, setViewMode] = useState<'burndown' | 'velocity'>('burndown')
  const [timeRange, setTimeRange] = useState<'all' | 'last7' | 'last30'>('all')
  const chartRef = useRef<HTMLDivElement>(null)

  // Calculate chart dimensions
  const chartWidth = 800
  const chartHeight = 400
  const padding = { top: 20, right: 80, bottom: 60, left: 60 }

  // Filter data based on time range
  const filteredData = useMemo(() => {
    if (timeRange === 'all') return burndownData

    const now = new Date()
    const days = timeRange === 'last7' ? 7 : 30
    const cutoffDate = new Date(now.getTime() - days * 24 * 60 * 60 * 1000)

    return burndownData.filter(point => new Date(point.date) >= cutoffDate)
  }, [burndownData, timeRange])

  // Calculate velocity metrics
  const velocityMetrics = useMemo(() => {
    if (filteredData.length < 2) return null

    const totalDays = filteredData.length
    const completedPoints = filteredData[filteredData.length - 1].completed - filteredData[0].completed
    const averageVelocity = completedPoints / totalDays

    // Calculate trend (slope of actual line)
    const firstPoint = filteredData[0]
    const lastPoint = filteredData[filteredData.length - 1]
    const trend = (lastPoint.actual - firstPoint.actual) / totalDays

    // Calculate projected completion date
    const remainingPoints = lastPoint.remaining
    const projectedDays = remainingPoints / Math.max(averageVelocity, 0.1)
    const projectedDate = new Date(lastPoint.date)
    projectedDate.setDate(projectedDate.getDate() + Math.ceil(projectedDays))

    return {
      averageVelocity: Math.round(averageVelocity * 100) / 100,
      trend,
      projectedDate,
      isOnTrack: trend <= 0, // Negative trend means we're burning down
      daysRemaining: Math.ceil(projectedDays)
    }
  }, [filteredData])

  // Calculate ideal burndown line
  const idealLine = useMemo(() => {
    if (filteredData.length === 0) return []

    const startDate = new Date(filteredData[0].date)
    const endDate = new Date(filteredData[filteredData.length - 1].date)
    const totalDays = Math.ceil((endDate.getTime() - startDate.getTime()) / (24 * 60 * 60 * 1000))
    const dailyBurnRate = filteredData[0].ideal / totalDays

    return filteredData.map((point, index) => ({
      ...point,
      ideal: Math.max(0, filteredData[0].ideal - (dailyBurnRate * index))
    }))
  }, [filteredData])

  // Convert data points to SVG coordinates
  const getPointCoordinates = useCallback((point: BurndownPoint, data: BurndownPoint[]) => {
    const maxValue = Math.max(...data.map(d => Math.max(d.ideal, d.actual, d.remaining)))
    const minDate = new Date(data[0].date)
    const maxDate = new Date(data[data.length - 1].date)
    const dateRange = maxDate.getTime() - minDate.getTime()

    const x = padding.left + ((new Date(point.date).getTime() - minDate.getTime()) / dateRange) * (chartWidth - padding.left - padding.right)
    const y = padding.top + ((maxValue - point.actual) / maxValue) * (chartHeight - padding.top - padding.bottom)

    return { x, y }
  }, [chartWidth, chartHeight, padding])

  // Generate SVG path for line
  const generatePath = useCallback((data: BurndownPoint[], key: keyof BurndownPoint) => {
    if (data.length === 0) return ''

    const maxValue = Math.max(...data.map(d => Math.max(d.ideal, d.actual, d.remaining)))
    const minDate = new Date(data[0].date)
    const maxDate = new Date(data[data.length - 1].date)
    const dateRange = maxDate.getTime() - minDate.getTime()

    const points = data.map((point, index) => {
      const x = padding.left + ((new Date(point.date).getTime() - minDate.getTime()) / dateRange) * (chartWidth - padding.left - padding.right)
      const y = padding.top + ((maxValue - (point[key] as number)) / maxValue) * (chartHeight - padding.top - padding.bottom)
      return `${index === 0 ? 'M' : 'L'} ${x} ${y}`
    })

    return points.join(' ')
  }, [chartWidth, chartHeight, padding])

  // Get status color and icon
  const getStatusInfo = (status: string) => {
    switch (status) {
      case 'completed':
        return { color: 'bg-green-100 text-green-800', icon: CheckCircle }
      case 'active':
        return { color: 'bg-blue-100 text-blue-800', icon: Clock }
      case 'cancelled':
        return { color: 'bg-red-100 text-red-800', icon: AlertTriangle }
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: Clock }
    }
  }

  // Calculate progress percentage
  const progressPercentage = sprint.totalStoryPoints > 0
    ? (sprint.completedStoryPoints / sprint.totalStoryPoints) * 100
    : 0

  const statusInfo = getStatusInfo(sprint.status)
  const StatusIcon = statusInfo.icon

  return (
    <Card className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold">{t('burndownChart', 'Burndown Chart')}</h2>
          <p className="text-sm text-gray-600 mt-1">
            {t('sprintProgress', 'Sprint Progress')}: {sprint.name}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {/* View Mode Toggle */}
          <div className="flex bg-gray-100 rounded-lg p-1">
            <Button
              variant={viewMode === 'burndown' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('burndown')}
              className="px-3 py-1"
            >
              <LineChart className="h-4 w-4 mr-1" />
              {t('burndown', 'Burndown')}
            </Button>
            <Button
              variant={viewMode === 'velocity' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('velocity')}
              className="px-3 py-1"
            >
              <BarChart3 className="h-4 w-4 mr-1" />
              {t('velocity', 'Velocity')}
            </Button>
          </div>

          {/* Time Range Filter */}
          <select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value as any)}
            className="px-3 py-2 border rounded-md text-sm"
          >
            <option value="all">{t('allTime', 'All Time')}</option>
            <option value="last30">{t('last30Days', 'Last 30 Days')}</option>
            <option value="last7">{t('last7Days', 'Last 7 Days')}</option>
          </select>

          <Button variant="outline" size="sm" onClick={onRefresh}>
            <RefreshCw className="h-4 w-4" />
          </Button>

          <Button variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            {t('export', 'Export')}
          </Button>
        </div>
      </div>

      {/* Sprint Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-blue-50 p-4 rounded-lg">
          <div className="flex items-center space-x-2 mb-2">
            <Target className="h-5 w-5 text-blue-600" />
            <span className="text-sm font-medium text-blue-600">{t('totalPoints', 'Total Points')}</span>
          </div>
          <div className="text-2xl font-bold text-blue-600">{sprint.totalStoryPoints}</div>
        </div>

        <div className="bg-green-50 p-4 rounded-lg">
          <div className="flex items-center space-x-2 mb-2">
            <CheckCircle className="h-5 w-5 text-green-600" />
            <span className="text-sm font-medium text-green-600">{t('completed', 'Completed')}</span>
          </div>
          <div className="text-2xl font-bold text-green-600">{sprint.completedStoryPoints}</div>
        </div>

        <div className="bg-orange-50 p-4 rounded-lg">
          <div className="flex items-center space-x-2 mb-2">
            <Clock className="h-5 w-5 text-orange-600" />
            <span className="text-sm font-medium text-orange-600">{t('remaining', 'Remaining')}</span>
          </div>
          <div className="text-2xl font-bold text-orange-600">
            {sprint.totalStoryPoints - sprint.completedStoryPoints}
          </div>
        </div>

        <div className="bg-purple-50 p-4 rounded-lg">
          <div className="flex items-center space-x-2 mb-2">
            <StatusIcon className="h-5 w-5 text-purple-600" />
            <span className="text-sm font-medium text-purple-600">{t('status', 'Status')}</span>
          </div>
          <Badge className={`text-sm ${statusInfo.color}`}>
            {sprint.status}
          </Badge>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="mb-6">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm font-medium">{t('sprintProgress', 'Sprint Progress')}</span>
          <span className="text-sm text-gray-600">{Math.round(progressPercentage)}%</span>
        </div>
        <Progress value={progressPercentage} className="h-3" />
        <div className="flex justify-between text-xs text-gray-500 mt-1">
          <span>{new Date(sprint.startDate).toLocaleDateString()}</span>
          <span>{new Date(sprint.endDate).toLocaleDateString()}</span>
        </div>
      </div>

      {/* Velocity Metrics */}
      {velocityMetrics && showVelocity && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <Card className="p-4">
            <div className="flex items-center space-x-2 mb-2">
              <TrendingUp className="h-4 w-4 text-blue-600" />
              <span className="text-sm font-medium">{t('averageVelocity', 'Average Velocity')}</span>
            </div>
            <div className="text-2xl font-bold">{velocityMetrics.averageVelocity}</div>
            <div className="text-xs text-gray-600">{t('pointsPerDay', 'points/day')}</div>
          </Card>

          <Card className="p-4">
            <div className="flex items-center space-x-2 mb-2">
              {velocityMetrics.isOnTrack ? (
                <TrendingDown className="h-4 w-4 text-green-600" />
              ) : (
                <TrendingUp className="h-4 w-4 text-red-600" />
              )}
              <span className="text-sm font-medium">{t('trend', 'Trend')}</span>
            </div>
            <div className={`text-2xl font-bold ${velocityMetrics.isOnTrack ? 'text-green-600' : 'text-red-600'}`}>
              {velocityMetrics.trend > 0 ? '+' : ''}{Math.round(velocityMetrics.trend * 100) / 100}
            </div>
            <div className="text-xs text-gray-600">{t('pointsPerDay', 'points/day')}</div>
          </Card>

          <Card className="p-4">
            <div className="flex items-center space-x-2 mb-2">
              <Calendar className="h-4 w-4 text-purple-600" />
              <span className="text-sm font-medium">{t('projectedCompletion', 'Projected Completion')}</span>
            </div>
            <div className="text-lg font-bold">{velocityMetrics.projectedDate.toLocaleDateString()}</div>
            <div className="text-xs text-gray-600">
              {velocityMetrics.daysRemaining} {t('daysRemaining', 'days remaining')}
            </div>
          </Card>
        </div>
      )}

      {/* Chart */}
      <div className="border rounded-lg bg-white p-4">
        <svg
          ref={chartRef}
          width={chartWidth}
          height={chartHeight}
          className="overflow-visible"
        >
          {/* Grid lines */}
          <defs>
            <pattern id="grid" width="40" height="20" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 20" fill="none" stroke="#f3f4f6" strokeWidth="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />

          {/* Ideal line */}
          {showIdealLine && idealLine.length > 0 && (
            <path
              d={generatePath(idealLine, 'ideal')}
              fill="none"
              stroke="#6B7280"
              strokeWidth="2"
              strokeDasharray="5,5"
            />
          )}

          {/* Actual burndown line */}
          {filteredData.length > 0 && (
            <path
              d={generatePath(filteredData, 'actual')}
              fill="none"
              stroke="#3B82F6"
              strokeWidth="3"
            />
          )}

          {/* Data points */}
          {filteredData.map((point, index) => {
            const coords = getPointCoordinates(point, filteredData)
            return (
              <circle
                key={index}
                cx={coords.x}
                cy={coords.y}
                r="4"
                fill="#3B82F6"
                stroke="#ffffff"
                strokeWidth="2"
                className="cursor-pointer hover:r-6"
                onMouseEnter={() => setSelectedPoint(point)}
                onMouseLeave={() => setSelectedPoint(null)}
              />
            )
          })}

          {/* Trend line */}
          {showTrendLine && velocityMetrics && filteredData.length > 1 && (
            <line
              x1={padding.left}
              y1={padding.top + ((Math.max(...filteredData.map(d => d.actual)) - filteredData[0].actual) /
                Math.max(...filteredData.map(d => d.actual))) * (chartHeight - padding.top - padding.bottom)}
              x2={chartWidth - padding.right}
              y2={padding.top + ((Math.max(...filteredData.map(d => d.actual)) - filteredData[filteredData.length - 1].actual) /
                Math.max(...filteredData.map(d => d.actual))) * (chartHeight - padding.top - padding.bottom)}
              stroke={velocityMetrics.isOnTrack ? '#10B981' : '#EF4444'}
              strokeWidth="2"
              strokeDasharray="10,5"
            />
          )}

          {/* Axes */}
          <line
            x1={padding.left}
            y1={padding.top}
            x2={padding.left}
            y2={chartHeight - padding.bottom}
            stroke="#6B7280"
            strokeWidth="1"
          />
          <line
            x1={padding.left}
            y1={chartHeight - padding.bottom}
            x2={chartWidth - padding.right}
            y2={chartHeight - padding.bottom}
            stroke="#6B7280"
            strokeWidth="1"
          />

          {/* Axis labels */}
          <text
            x={chartWidth / 2}
            y={chartHeight - 10}
            textAnchor="middle"
            className="text-sm fill-gray-600"
          >
            {t('date', 'Date')}
          </text>
          <text
            x={15}
            y={chartHeight / 2}
            textAnchor="middle"
            transform={`rotate(-90 15 ${chartHeight / 2})`}
            className="text-sm fill-gray-600"
          >
            {t('storyPoints', 'Story Points')}
          </text>
        </svg>
      </div>

      {/* Legend */}
      <div className="flex flex-wrap items-center justify-center gap-6 mt-4 text-sm">
        <div className="flex items-center space-x-2">
          <div className="w-4 h-0.5 bg-blue-500"></div>
          <span>{t('actualBurndown', 'Actual Burndown')}</span>
        </div>
        {showIdealLine && (
          <div className="flex items-center space-x-2">
            <div className="w-4 h-0.5 bg-gray-500 border-dashed border-t-2"></div>
            <span>{t('idealBurndown', 'Ideal Burndown')}</span>
          </div>
        )}
        {showTrendLine && (
          <div className="flex items-center space-x-2">
            <div className="w-4 h-0.5 bg-green-500 border-dashed border-t-2"></div>
            <span>{t('trendLine', 'Trend Line')}</span>
          </div>
        )}
      </div>

      {/* Tooltip */}
      {selectedPoint && (
        <Card className="absolute z-10 p-3 shadow-lg border bg-white">
          <div className="text-sm">
            <div className="font-medium mb-2">{new Date(selectedPoint.date).toLocaleDateString()}</div>
            <div className="space-y-1">
              <div className="flex justify-between">
                <span>{t('remaining', 'Remaining')}:</span>
                <span className="font-medium">{selectedPoint.remaining}</span>
              </div>
              <div className="flex justify-between">
                <span>{t('completed', 'Completed')}:</span>
                <span className="font-medium">{selectedPoint.completed}</span>
              </div>
              <div className="flex justify-between">
                <span>{t('ideal', 'Ideal')}:</span>
                <span className="font-medium">{selectedPoint.ideal}</span>
              </div>
            </div>
          </div>
        </Card>
      )}
    </Card>
  )
}
