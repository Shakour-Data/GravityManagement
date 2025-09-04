'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select'
import { Alert } from '@/components/ui/alert'
import { Loader2 } from 'lucide-react'
import { useCreateResource, useProjects } from '@/lib/hooks'

export default function CreateResourcePage() {
  const { t } = useTranslation('common')
  const router = useRouter()

  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [type, setType] = useState<'human' | 'material' | 'financial'>('human')
  const [projectId, setProjectId] = useState('')
  const [quantity, setQuantity] = useState('')
  const [cost, setCost] = useState('')
  const [availability, setAvailability] = useState(true)
  const [skillLevel, setSkillLevel] = useState('')
  const [location, setLocation] = useState('')

  const createResource = useCreateResource()
  const { data: projects, loading: projectsLoading } = useProjects()

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    try {
      await createResource.mutate({
        name,
        description,
        type,
        project_id: projectId,
        quantity: quantity ? parseFloat(quantity) : undefined,
        cost: cost ? parseFloat(cost) : undefined,
        availability,
        skill_level: skillLevel ? parseInt(skillLevel) : undefined,
        location: location || undefined
      })
      router.push('/resources')
    } catch (error) {
      console.error('Failed to create resource:', error)
    }
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-3xl font-bold">{t('createResource', 'Create Resource')}</h1>
        <Button variant="outline" onClick={() => router.back()}>
          {t('cancel', 'Cancel')}
        </Button>
      </div>

      {createResource.error && (
        <Alert variant="destructive" className="mb-4">
          {createResource.error}
        </Alert>
      )}

      <Card className="p-6">
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
              {t('resourceName', 'Resource Name')} *
            </label>
            <Input
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder={t('enterResourceName', 'Enter resource name')}
            />
          </div>

          <div>
            <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-2">
              {t('description', 'Description')}
            </label>
            <Textarea
              id="description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder={t('enterResourceDescription', 'Enter resource description')}
              rows={4}
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="type" className="block text-sm font-medium text-gray-700 mb-2">
                {t('type', 'Type')} *
              </label>
              <Select value={type} onValueChange={(value: 'human' | 'material' | 'financial') => setType(value)}>
                <SelectTrigger>
                  <SelectValue placeholder={t('selectType', 'Select type')} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="human">{t('human', 'Human')}</SelectItem>
                  <SelectItem value="material">{t('material', 'Material')}</SelectItem>
                  <SelectItem value="financial">{t('financial', 'Financial')}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <label htmlFor="project" className="block text-sm font-medium text-gray-700 mb-2">
                {t('project', 'Project')}
              </label>
              <Select value={projectId} onValueChange={setProjectId}>
                <SelectTrigger>
                  <SelectValue placeholder={t('selectProject', 'Select a project')} />
                </SelectTrigger>
                <SelectContent>
                  {projectsLoading ? (
                    <SelectItem value="" disabled>
                      {t('loading', 'Loading...')}
                    </SelectItem>
                  ) : (
                    (projects as any[])?.map((project: any) => (
                      <SelectItem key={project.id} value={project.id}>
                        {project.name}
                      </SelectItem>
                    ))
                  )}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label htmlFor="quantity" className="block text-sm font-medium text-gray-700 mb-2">
                {t('quantity', 'Quantity')}
              </label>
              <Input
                id="quantity"
                type="number"
                step="0.01"
                value={quantity}
                onChange={(e) => setQuantity(e.target.value)}
                placeholder={t('enterQuantity', 'Enter quantity')}
              />
            </div>

            <div>
              <label htmlFor="cost" className="block text-sm font-medium text-gray-700 mb-2">
                {t('cost', 'Cost')} ({t('currency', 'USD')})
              </label>
              <Input
                id="cost"
                type="number"
                step="0.01"
                value={cost}
                onChange={(e) => setCost(e.target.value)}
                placeholder={t('enterCost', 'Enter cost')}
              />
            </div>
          </div>

          {type === 'human' && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label htmlFor="skillLevel" className="block text-sm font-medium text-gray-700 mb-2">
                  {t('skillLevel', 'Skill Level')} (1-5)
                </label>
                <Select value={skillLevel} onValueChange={setSkillLevel}>
                  <SelectTrigger>
                    <SelectValue placeholder={t('selectSkillLevel', 'Select skill level')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">1 - {t('beginner', 'Beginner')}</SelectItem>
                    <SelectItem value="2">2 - {t('novice', 'Novice')}</SelectItem>
                    <SelectItem value="3">3 - {t('intermediate', 'Intermediate')}</SelectItem>
                    <SelectItem value="4">4 - {t('advanced', 'Advanced')}</SelectItem>
                    <SelectItem value="5">5 - {t('expert', 'Expert')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div>
                <label htmlFor="location" className="block text-sm font-medium text-gray-700 mb-2">
                  {t('location', 'Location')}
                </label>
                <Input
                  id="location"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  placeholder={t('enterLocation', 'Enter location')}
                />
              </div>
            </div>
          )}

          <div className="flex items-center space-x-2">
            <input
              type="checkbox"
              id="availability"
              checked={availability}
              onChange={(e) => setAvailability(e.target.checked)}
              className="rounded"
            />
            <label htmlFor="availability" className="text-sm font-medium text-gray-700">
              {t('available', 'Available')}
            </label>
          </div>

          <div className="flex space-x-4">
            <Button
              type="submit"
              disabled={createResource.loading || !name}
              className="flex-1"
            >
              {createResource.loading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  {t('creating', 'Creating...')}
                </>
              ) : (
                t('createResource', 'Create Resource')
              )}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
              className="flex-1"
            >
              {t('cancel', 'Cancel')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  )
}
