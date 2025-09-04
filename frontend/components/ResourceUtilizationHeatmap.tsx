'use client'

import React, { useState, useMemo, useCallback } from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import {
  Calendar,
  Users,
  AlertTriangle,
  CheckCircle,
  Clock,
  TrendingUp,
  TrendingDown,
  Filter,
  Download,
  Settings,
  ZoomIn,
  ZoomOut,
  RefreshCw
} from 'lucide-react'

interface ResourceUtilization {
  resourceId: string
  resourceName: string
  resourceType: 'human' | 'material' | 'financial'
  date: string
  utilization: number // percentage 0-100
  capacity: number
  allocated: number
  available: number
}

interface HeatmapCell {
  date: string
  resourceId: string
  utilization: number
  status: 'low' | 'medium' | 'high' | 'critical' | 'overallocated'
}

interface ResourceUtilizationHeatmapProps {
  data: ResourceUtilization[]
  startDate: Date
  endDate: Date
  onCellClick: (resourceId: string, date: string) => void
  onResourceFilter: (resourceType: string) => void
  onDateRangeChange: (startDate: Date, endDate: Date) => void
}

export default function ResourceUtilizationHeatmap({
  data,
  startDate,
  endDate,
  onCellClick,
  onResourceFilter,
  onDateRangeChange
}: ResourceUtilizationHeatmapProps) {
  const { t } = useTranslation('common')
  const [selectedResource, setSelectedResource] = useState<string | null>(null)
  const [selectedDate, setSelectedDate] = useState<string | null>(null)
  const [resourceTypeFilter, setResourceTypeFilter] = useState<string>('all')
  const [viewMode, setViewMode] = useState<'monthly' | 'weekly'>('monthly')
  const [zoom, setZoom] = useState(1)

  // Process data into heatmap format
  const heatmapData = useMemo(() => {
    const filteredData = resourceTypeFilter === 'all'
      ? data
      : data.filter(item => item.resourceType === resourceTypeFilter)

    const resources = Array.from(new Set(filteredData.map(item => item.resourceId)))
    const dates: string[] = []

    // Generate date range
    const current = new Date(startDate)
    while (current <= endDate) {
      dates.push(current.toISOString().split('T')[0])
      current.setDate(current.getDate() + 1)
    }

    // Create heatmap matrix
    const matrix: HeatmapCell[][] = []

    resources.forEach(resourceId => {
      const resourceRow: HeatmapCell[] = []

      dates.forEach(date => {
        const utilizationData = filteredData.find(
          item => item.resourceId === resourceId && item.date === date
        )

        let utilization = 0
        let status: HeatmapCell['status'] = 'low'

        if (utilizationData) {
          utilization = utilizationData.utilization

          if (utilization > 100) {
            status = 'overallocated'
          } else if (utilization >= 80) {
            status = 'critical'
          } else if (utilization >= 60) {
            status = 'high'
          } else if (utilization >= 30) {
            status = 'medium'
          } else {
            status = 'low'
          }
        }

        resourceRow.push({
          date,
          resourceId,
          utilization,
          status
        })
      })

      matrix.push(resourceRow)
    })

    return { matrix, resources, dates }
  }, [data, startDate, endDate, resourceTypeFilter])

  // Get resource info
  const getResourceInfo = useCallback((resourceId: string) => {
    const resourceData = data.find(item => item.resourceId === resourceId)
    return resourceData || {
      resourceName: 'Unknown Resource',
      resourceType: 'human' as const,
      capacity: 0
    }
  }, [data])

  // Get cell color based on utilization
  const getCellColor = (status: HeatmapCell['status']) => {
    switch (status) {
      case 'overallocated': return 'bg-red-600'
      case 'critical': return 'bg-red-400'
      case 'high': return 'bg-orange-400'
      case 'medium': return 'bg-yellow-400'
      case 'low': return 'bg-green-400'
      default: return 'bg-gray-200'
    }
  }

  // Get cell intensity based on utilization value
  const getCellIntensity = (utilization: number) => {
    if (utilization === 0) return 'bg-gray-100'
    if (utilization > 100) return 'bg-red-700'
    if (utilization >= 90) return 'bg-red-500'
    if (utilization >= 80) return 'bg-red-400'
    if (utilization >= 70) return 'bg-orange-500'
    if (utilization >= 60) return 'bg-orange-400'
    if (utilization >= 50) return 'bg-yellow-500'
    if (utilization >= 40) return 'bg-yellow-400'
    if (utilization >= 30) return 'bg-green-500'
    if (utilization >= 20) return 'bg-green-400'
    return 'bg-green-300'
  }

  // Calculate summary statistics
  const summaryStats = useMemo(() => {
    const filteredData = resourceTypeFilter === 'all'
      ? data
      : data.filter(item => item.resourceType === resourceTypeFilter)

    const totalCells = filteredData.length
    const overallocated = filteredData.filter(item => item.utilization > 100).length
    const critical = filteredData.filter(item => item.utilization >= 80 && item.utilization <= 100).length
    const high = filteredData.filter(item => item.utilization >= 60 && item.utilization < 80).length
    const medium = filteredData.filter(item => item.utilization >= 30 && item.utilization < 60).length
    const low = filteredData.filter(item => item.utilization > 0 && item.utilization < 30).length
    const unused = filteredData.filter(item => item.utilization === 0).length

    const averageUtilization = totalCells > 0
      ? filteredData.reduce((sum, item) => sum + item.utilization, 0) / totalCells
      : 0

    return {
      totalCells,
      overallocated,
      critical,
      high,
      medium,
      low,
      unused,
      averageUtilization: Math.round(averageUtilization * 100) / 100
    }
  }, [data, resourceTypeFilter])

  // Handle cell click
  const handleCellClick = (cell: HeatmapCell) => {
    setSelectedResource(cell.resourceId)
    setSelectedDate(cell.date)
    onCellClick(cell.resourceId, cell.date)
  }

  // Format date for display
  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      ...(viewMode === 'monthly' && { year: 'numeric' })
    })
  }

  // Get resource type icon
  const getResourceTypeIcon = (type: string) => {
    switch (type) {
      case 'human': return <Users className="h-4 w-4" />
      case 'material': return <Settings className="h-4 w-4" />
      case 'financial': return <TrendingUp className="h-4 w-4" />
      default: return <Users className="h-4 w-4" />
    }
  }

  return (
    <Card className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-semibold">{t('resourceUtilizationHeatmap', 'Resource Utilization Heatmap')}</h2>
          <p className="text-sm text-gray-600 mt-1">
            {t('heatmapDescription', 'Visualize resource utilization patterns over time')}
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {/* View Mode */}
          <div className="flex bg-gray-100 rounded-lg p-1">
            <Button
              variant={viewMode === 'monthly' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('monthly')}
              className="px-3 py-1"
            >
              <Calendar className="h-4 w-4 mr-1" />
              {t('monthly', 'Monthly')}
            </Button>
            <Button
              variant={viewMode === 'weekly' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setViewMode('weekly')}
              className="px-3 py-1"
            >
              <Calendar className="h-4 w-4 mr-1" />
              {t('weekly', 'Weekly')}
            </Button>
          </div>

          {/* Resource Type Filter */}
          <select
            value={resourceTypeFilter}
            onChange={(e) => {
              setResourceTypeFilter(e.target.value)
              onResourceFilter(e.target.value)
            }}
            className="px-3 py-2 border rounded-md text-sm"
          >
            <option value="all">{t('allResources', 'All Resources')}</option>
            <option value="human">{t('humanResources', 'Human')}</option>
            <option value="material">{t('materialResources', 'Material')}</option>
            <option value="financial">{t('financialResources', 'Financial')}</option>
          </select>

          {/* Zoom Controls */}
          <Button variant="outline" size="sm" onClick={() => setZoom(Math.max(0.5, zoom - 0.25))}>
            <ZoomOut className="h-4 w-4" />
          </Button>
          <span className="text-sm text-gray-600 min-w-[60px] text-center">
            {Math.round(zoom * 100)}%
          </span>
          <Button variant="outline" size="sm" onClick={() => setZoom(Math.min(2, zoom + 0.25))}>
            <ZoomIn className="h-4 w-4" />
          </Button>

          <Button variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            {t('export', 'Export')}
          </Button>
        </div>
      </div>

      {/* Summary Statistics */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4 mb-6">
        <div className="bg-blue-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-blue-600">{summaryStats.totalCells}</div>
          <div className="text-xs text-blue-600">{t('totalDataPoints', 'Total Data Points')}</div>
        </div>
        <div className="bg-red-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-red-600">{summaryStats.overallocated}</div>
          <div className="text-xs text-red-600">{t('overallocated', 'Overallocated')}</div>
        </div>
        <div className="bg-orange-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-orange-600">{summaryStats.critical}</div>
          <div className="text-xs text-orange-600">{t('critical', 'Critical')}</div>
        </div>
        <div className="bg-yellow-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-yellow-600">{summaryStats.high}</div>
          <div className="text-xs text-yellow-600">{t('highUtilization', 'High')}</div>
        </div>
        <div className="bg-green-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-green-600">{summaryStats.medium}</div>
          <div className="text-xs text-green-600">{t('mediumUtilization', 'Medium')}</div>
        </div>
        <div className="bg-gray-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-gray-600">{summaryStats.low}</div>
          <div className="text-xs text-gray-600">{t('lowUtilization', 'Low')}</div>
        </div>
        <div className="bg-purple-50 p-3 rounded-lg">
          <div className="text-lg font-bold text-purple-600">{summaryStats.averageUtilization}%</div>
          <div className="text-xs text-purple-600">{t('averageUtilization', 'Avg Utilization')}</div>
        </div>
      </div>

      {/* Heatmap */}
      <div className="overflow-x-auto overflow-y-auto max-h-96 border rounded-lg bg-white">
        <div className="inline-block min-w-full">
          {/* Header Row with Dates */}
          <div className="flex sticky top-0 bg-gray-50 border-b">
            <div className="w-48 p-3 font-semibold border-r bg-gray-100 flex items-center">
              {t('resources', 'Resources')}
            </div>
            {heatmapData.dates.map((date, index) => (
              <div
                key={date}
                className="w-8 p-2 text-center border-r text-xs font-medium text-gray-600"
                style={{ minWidth: `${32 * zoom}px` }}
                title={new Date(date).toLocaleDateString()}
              >
                <div className="transform -rotate-45 origin-center whitespace-nowrap">
                  {formatDate(date)}
                </div>
              </div>
            ))}
          </div>

          {/* Resource Rows */}
          {heatmapData.matrix.map((row, rowIndex) => {
            const resourceId = heatmapData.resources[rowIndex]
            const resourceInfo = getResourceInfo(resourceId)

            return (
              <div key={resourceId} className="flex border-b hover:bg-gray-50">
                {/* Resource Name Column */}
                <div className="w-48 p-3 border-r bg-gray-50 flex items-center space-x-2">
                  {getResourceTypeIcon(resourceInfo.resourceType)}
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-sm truncate" title={resourceInfo.resourceName}>
                      {resourceInfo.resourceName}
                    </div>
                    <Badge className={`text-xs ${
                      resourceInfo.resourceType === 'human' ? 'bg-blue-100 text-blue-800' :
                      resourceInfo.resourceType === 'material' ? 'bg-green-100 text-green-800' :
                      'bg-yellow-100 text-yellow-800'
                    }`}>
                      {resourceInfo.resourceType}
                    </Badge>
                  </div>
                </div>

                {/* Data Cells */}
                {row.map((cell, cellIndex) => (
                  <div
                    key={`${cell.resourceId}-${cell.date}`}
                    className={`w-8 h-8 border-r cursor-pointer transition-all duration-200 ${
                      selectedResource === cell.resourceId && selectedDate === cell.date
                        ? 'ring-2 ring-blue-500'
                        : ''
                    }`}
                    style={{
                      minWidth: `${32 * zoom}px`,
                      minHeight: `${32 * zoom}px`
                    }}
                    onClick={() => handleCellClick(cell)}
                    title={`${resourceInfo.resourceName} - ${formatDate(cell.date)}: ${cell.utilization}%`}
                  >
                    <div
                      className={`w-full h-full ${getCellIntensity(cell.utilization)} hover:opacity-80 transition-opacity`}
                    />
                  </div>
                ))}
              </div>
            )
          })}
        </div>
      </div>

      {/* Legend */}
      <div className="flex flex-wrap items-center justify-center gap-4 mt-4 text-sm">
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-red-700 rounded"></div>
          <span>{t('overallocated', 'Overallocated')} (>100%)</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-red-400 rounded"></div>
          <span>{t('critical', 'Critical')} (80-100%)</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-orange-400 rounded"></div>
          <span>{t('high', 'High')} (60-80%)</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-yellow-400 rounded"></div>
          <span>{t('medium', 'Medium')} (30-60%)</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-green-400 rounded"></div>
          <span>{t('low', 'Low')} (1-30%)</span>
        </div>
        <div className="flex items-center space-x-2">
          <div className="w-4 h-4 bg-gray-200 rounded"></div>
          <span>{t('unused', 'Unused')} (0%)</span>
        </div>
      </div>

      {/* Selected Cell Details */}
      {selectedResource && selectedDate && (
        <Card className="mt-4 p-4">
          <h3 className="font-semibold mb-3">{t('resourceDetails', 'Resource Details')}</h3>
          {(() => {
            const resourceInfo = getResourceInfo(selectedResource)
            const cellData = data.find(
              item => item.resourceId === selectedResource && item.date === selectedDate
            )

            if (!cellData) return null

            return (
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('resource', 'Resource')}</label>
                  <div className="text-sm mt-1">{resourceInfo.resourceName}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('date', 'Date')}</label>
                  <div className="text-sm mt-1">{new Date(selectedDate).toLocaleDateString()}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('utilization', 'Utilization')}</label>
                  <div className="text-sm mt-1">
                    <Progress value={cellData.utilization} className="h-2" />
                    <span className="text-xs text-gray-600">{cellData.utilization}%</span>
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('capacity', 'Capacity')}</label>
                  <div className="text-sm mt-1">{cellData.capacity}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('allocated', 'Allocated')}</label>
                  <div className="text-sm mt-1">{cellData.allocated}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('available', 'Available')}</label>
                  <div className="text-sm mt-1">{cellData.available}</div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('status', 'Status')}</label>
                  <div className="text-sm mt-1">
                    <Badge className={`text-xs ${
                      cellData.utilization > 100 ? 'bg-red-100 text-red-800' :
                      cellData.utilization >= 80 ? 'bg-orange-100 text-orange-800' :
                      cellData.utilization >= 60 ? 'bg-yellow-100 text-yellow-800' :
                      cellData.utilization > 0 ? 'bg-green-100 text-green-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {cellData.utilization > 100 ? t('overallocated', 'Overallocated') :
                       cellData.utilization >= 80 ? t('critical', 'Critical') :
                       cellData.utilization >= 60 ? t('high', 'High') :
                       cellData.utilization >= 30 ? t('medium', 'Medium') :
                       cellData.utilization > 0 ? t('low', 'Low') :
                       t('unused', 'Unused')}
                    </Badge>
                  </div>
                </div>
              </div>
            )
          })()}
        </Card>
      )}
    </Card>
  )
}
