'use client'

import React, { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { Alert } from '@/components/ui/alert'
import { Loader2, Edit, Trash2, ArrowLeft, Calendar, Users, Package, DollarSign, Plus } from 'lucide-react'
import { useResource, useUpdateResource, useDeleteResource } from '@/lib/hooks'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'

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

export default function ResourceDetailsPage() {
  const params = useParams()
  const router = useRouter()
  const { t } = useTranslation('common')
  const id = params.id as string

  const { data: resource, loading, error } = useResource(id)
  const [isEditing, setIsEditing] = useState(false)
  const [editForm, setEditForm] = useState({
    name: '',
    description: '',
    quantity: '',
    cost: '',
    availability: true
  })

  React.useEffect(() => {
    if (resource) {
      const typedResource = resource as Resource
      setEditForm({
        name: typedResource.name || '',
        description: typedResource.description || '',
        quantity: typedResource.quantity?.toString() || '',
        cost: typedResource.cost?.toString() || '',
        availability: typedResource.availability || true
      })
    }
  }, [resource])

  const updateResource = useUpdateResource(id)
  const deleteResource = useDeleteResource()

  const handleUpdate = async () => {
    try {
      await updateResource.mutate({
        name: editForm.name,
        description: editForm.description,
        quantity: editForm.quantity ? parseFloat(editForm.quantity) : undefined,
        cost: editForm.cost ? parseFloat(editForm.cost) : undefined,
        availability: editForm.availability
      })
      setIsEditing(false)
    } catch (error) {
      console.error('Failed to update resource:', error)
    }
  }

  const handleDelete = async () => {
    if (window.confirm(t('confirmDeleteResource', 'Are you sure you want to delete this resource?'))) {
      try {
        await deleteResource.mutate(id)
        router.push('/resources')
      } catch (error) {
        console.error('Failed to delete resource:', error)
      }
    }
  }

  if (loading) {
    return (
      <div className="flex justify-center py-8">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (error || !resource) {
    return (
      <div className="p-6">
        <Alert variant="destructive">
          {t('failedToLoadResource', 'Failed to load resource')}: {error}
        </Alert>
        <Button onClick={() => router.back()} className="mt-4">
          <ArrowLeft className="h-4 w-4 mr-2" />
          {t('back', 'Back')}
        </Button>
      </div>
    )
  }

  const typedResource = resource as Resource

  // Prepare utilization chart data
  const utilizationChartData = typedResource.utilization_history.map((entry: any) => ({
    date: new Date(entry.period_start).toLocaleDateString(),
    utilization: entry.utilization_percentage
  }))

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center space-x-4">
          <Button onClick={() => router.back()} variant="outline">
            <ArrowLeft className="h-4 w-4 mr-2" />
            {t('back', 'Back')}
          </Button>
          <h1 className="text-3xl font-bold">{typedResource.name}</h1>
        </div>
        <div className="flex space-x-2">
          <Button
            variant="outline"
            onClick={() => setIsEditing(!isEditing)}
          >
            <Edit className="h-4 w-4 mr-2" />
            {isEditing ? t('cancel', 'Cancel') : t('edit', 'Edit')}
          </Button>
          <Button variant="destructive" onClick={handleDelete}>
            <Trash2 className="h-4 w-4 mr-2" />
            {t('delete', 'Delete')}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        {/* Resource Info */}
        <Card className="p-6 lg:col-span-2">
          <h2 className="text-xl font-semibold mb-4">{t('resourceDetails', 'Resource Details')}</h2>
          {isEditing ? (
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('name', 'Name')}</label>
                <Input
                  value={editForm.name}
                  onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                  className="mt-1"
                />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-600">{t('description', 'Description')}</label>
                <Textarea
                  value={editForm.description}
                  onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                  className="mt-1"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('quantity', 'Quantity')}</label>
                  <Input
                    type="number"
                    value={editForm.quantity}
                    onChange={(e) => setEditForm({ ...editForm, quantity: e.target.value })}
                    className="mt-1"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('cost', 'Cost')}</label>
                  <Input
                    type="number"
                    value={editForm.cost}
                    onChange={(e) => setEditForm({ ...editForm, cost: e.target.value })}
                    className="mt-1"
                  />
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  checked={editForm.availability}
                  onChange={(e) => setEditForm({ ...editForm, availability: e.target.checked })}
                  className="rounded"
                />
                <label className="text-sm font-medium text-gray-600">{t('available', 'Available')}</label>
              </div>
              <div className="flex space-x-2">
                <Button onClick={handleUpdate} disabled={updateResource.loading}>
                  {updateResource.loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                  {t('save', 'Save')}
                </Button>
                <Button variant="outline" onClick={() => setIsEditing(false)}>
                  {t('cancel', 'Cancel')}
                </Button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-gray-600">{t('description', 'Description')}</label>
                <p className="mt-1">{typedResource.description || t('noDescription', 'No description provided')}</p>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('type', 'Type')}</label>
                  <div className="mt-1">
                    <Badge variant={
                      typedResource.type === 'human' ? 'default' :
                      typedResource.type === 'material' ? 'secondary' :
                      'outline'
                    }>
                      {typedResource.type === 'human' && <Users className="h-3 w-3 mr-1" />}
                      {typedResource.type === 'material' && <Package className="h-3 w-3 mr-1" />}
                      {typedResource.type === 'financial' && <DollarSign className="h-3 w-3 mr-1" />}
                      {typedResource.type}
                    </Badge>
                  </div>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('availability', 'Availability')}</label>
                  <div className="mt-1">
                    <Badge variant={typedResource.availability ? 'default' : 'secondary'}>
                      {typedResource.availability ? t('available', 'Available') : t('unavailable', 'Unavailable')}
                    </Badge>
                  </div>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('quantity', 'Quantity')}</label>
                  <p className="mt-1">{typedResource.quantity || '-'}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('cost', 'Cost')}</label>
                  <p className="mt-1">{typedResource.cost ? `$${typedResource.cost}` : '-'}</p>
                </div>
              </div>
              {typedResource.skill_level && (
                <div>
                  <label className="text-sm font-medium text-gray-600">{t('skillLevel', 'Skill Level')}</label>
                  <p className="mt-1">{typedResource.skill_level}/5</p>
                </div>
              )}
            </div>
          )}
        </Card>

        {/* Quick Stats */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('quickStats', 'Quick Stats')}</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Package className="h-5 w-5 text-blue-500" />
                <span className="text-sm">{t('currentUtilization', 'Current Utilization')}</span>
              </div>
              <span className="font-semibold">
                {typedResource.utilization_history.length > 0
                  ? `${typedResource.utilization_history[typedResource.utilization_history.length - 1].utilization_percentage}%`
                  : '0%'
                }
              </span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <Calendar className="h-5 w-5 text-green-500" />
                <span className="text-sm">{t('activeAllocations', 'Active Allocations')}</span>
              </div>
              <span className="font-semibold">{typedResource.allocations.length}</span>
            </div>
          </div>
        </Card>
      </div>

      {/* Utilization Chart */}
      <Card className="p-6 mb-6">
        <h2 className="text-xl font-semibold mb-4">{t('utilizationHistory', 'Utilization History')}</h2>
        {utilizationChartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={utilizationChartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="utilization" stroke="#8884d8" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div className="text-center py-8 text-gray-500">
            {t('noUtilizationData', 'No utilization data available')}
          </div>
        )}
      </Card>

      {/* Allocations */}
      <Card className="p-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold">{t('allocations', 'Allocations')}</h2>
          <Button size="sm">
            <Plus className="h-4 w-4 mr-2" />
            {t('addAllocation', 'Add Allocation')}
          </Button>
        </div>
        {typedResource.allocations.length > 0 ? (
          <div className="space-y-4">
            {typedResource.allocations.map((allocation: any, index: number) => (
              <div key={index} className="border rounded-lg p-4">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="font-medium">{allocation.task_id}</h3>
                    <p className="text-sm text-gray-600">
                      {t('allocatedQuantity', 'Allocated Quantity')}: {allocation.allocated_quantity}
                    </p>
                    <p className="text-sm text-gray-600">
                      {t('period', 'Period')}: {new Date(allocation.start_date).toLocaleDateString()} - {allocation.end_date ? new Date(allocation.end_date).toLocaleDateString() : t('ongoing', 'Ongoing')}
                    </p>
                  </div>
                  <Badge variant="outline">{t('active', 'Active')}</Badge>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-8 text-gray-500">
            {t('noAllocations', 'No allocations found')}
          </div>
        )}
      </Card>
    </div>
  )
}
