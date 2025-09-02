'use client'

import React, { useState } from 'react'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { Table } from '@/components/ui/table'
import { Loader2, Plus, Edit, Trash2, Users, Package, DollarSign } from 'lucide-react'
import { useResources, useCreateResource, useUpdateResource, useDeleteResource } from '@/lib/hooks'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts'

interface Resource {
  id: string
  name: string
  type: 'human' | 'material' | 'financial'
  description?: string
  project_id: string
  quantity?: number
  cost?: number
  availability: boolean
  skill_level?: number
  location?: string
  allocations: any[]
  utilization_history: any[]
}

export default function ResourcesPage() {
  const { t } = useTranslation('common')
  const { data: resources, loading, error } = useResources()
  const [filterType, setFilterType] = useState<string>('all')
  const [searchTerm, setSearchTerm] = useState('')
  const [showCreateForm, setShowCreateForm] = useState(false)

  const filteredResources = (resources as Resource[])?.filter((resource: Resource) => {
    const matchesType = filterType === 'all' || resource.type === filterType
    const matchesSearch = resource.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         resource.description?.toLowerCase().includes(searchTerm.toLowerCase())
    return matchesType && matchesSearch
  }) || []

  // Calculate utilization data for charts
  const utilizationData = filteredResources.map((resource: Resource) => ({
    name: resource.name,
    utilization: resource.utilization_history.length > 0
      ? resource.utilization_history[resource.utilization_history.length - 1].utilization_percentage
      : 0
  }))

  const typeDistribution = [
    { name: 'Human', value: filteredResources.filter(r => r.type === 'human').length, color: '#8884d8' },
    { name: 'Material', value: filteredResources.filter(r => r.type === 'material').length, color: '#82ca9d' },
    { name: 'Financial', value: filteredResources.filter(r => r.type === 'financial').length, color: '#ffc658' }
  ]

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
        {t('failedToLoadResources', 'Failed to load resources')}: {error}
      </div>
    )
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">{t('resources', 'Resources')}</h1>
        <Button onClick={() => setShowCreateForm(true)}>
          <Plus className="h-4 w-4 mr-2" />
          {t('addResource', 'Add Resource')}
        </Button>
      </div>

      {/* Filters */}
      <Card className="p-4 mb-6">
        <div className="flex gap-4">
          <Input
            placeholder={t('searchResources', 'Search resources...')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1"
          />
          <Select value={filterType} onValueChange={setFilterType}>
            <option value="all">{t('allTypes', 'All Types')}</option>
            <option value="human">{t('human', 'Human')}</option>
            <option value="material">{t('material', 'Material')}</option>
            <option value="financial">{t('financial', 'Financial')}</option>
          </Select>
        </div>
      </Card>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card className="p-4">
          <h3 className="text-lg font-semibold mb-4">{t('resourceUtilization', 'Resource Utilization')}</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={utilizationData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="utilization" fill="#8884d8" />
            </BarChart>
          </ResponsiveContainer>
        </Card>

        <Card className="p-4">
          <h3 className="text-lg font-semibold mb-4">{t('resourceTypes', 'Resource Types')}</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={typeDistribution}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, percent }) => `${name} ${(percent ? (percent * 100).toFixed(0) : 0)}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {typeDistribution.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </Card>
      </div>

      {/* Resources Table */}
      <Card className="p-4">
        <h3 className="text-lg font-semibold mb-4">{t('resourceList', 'Resource List')}</h3>
        <Table>
          <thead>
            <tr>
              <th>{t('name', 'Name')}</th>
              <th>{t('type', 'Type')}</th>
              <th>{t('quantity', 'Quantity')}</th>
              <th>{t('cost', 'Cost')}</th>
              <th>{t('availability', 'Availability')}</th>
              <th>{t('actions', 'Actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredResources.map((resource: Resource) => (
              <tr key={resource.id}>
                <td>
                  <div>
                    <div className="font-medium">{resource.name}</div>
                    {resource.description && (
                      <div className="text-sm text-gray-500">{resource.description}</div>
                    )}
                  </div>
                </td>
                <td>
                  <Badge variant={
                    resource.type === 'human' ? 'default' :
                    resource.type === 'material' ? 'secondary' :
                    'outline'
                  }>
                    {resource.type === 'human' && <Users className="h-3 w-3 mr-1" />}
                    {resource.type === 'material' && <Package className="h-3 w-3 mr-1" />}
                    {resource.type === 'financial' && <DollarSign className="h-3 w-3 mr-1" />}
                    {resource.type}
                  </Badge>
                </td>
                <td>{resource.quantity || '-'}</td>
                <td>{resource.cost ? `$${resource.cost}` : '-'}</td>
                <td>
                  <Badge variant={resource.availability ? 'default' : 'secondary'}>
                    {resource.availability ? t('available', 'Available') : t('unavailable', 'Unavailable')}
                  </Badge>
                </td>
                <td>
                  <div className="flex space-x-2">
                    <Link href={`/resources/${resource.id}`}>
                      <Button variant="outline" size="sm">
                        <Edit className="h-4 w-4" />
                      </Button>
                    </Link>
                    <Button variant="outline" size="sm">
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
        {filteredResources.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            {t('noResourcesFound', 'No resources found')}
          </div>
        )}
      </Card>
    </div>
  )
}
