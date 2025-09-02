'use client'

import React, { useState } from 'react'
import { useTranslation } from 'next-i18next'
import Link from 'next/link'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Table } from '@/components/ui/table'
import { Alert } from '@/components/ui/alert'
import { Loader2, Plus, Search, Edit, Eye, Trash2, Filter } from 'lucide-react'
import { useProjects, useDeleteProject } from '@/lib/hooks'

export default function ProjectsPage() {
  const { t } = useTranslation('common')
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('')

  // Fetch projects
  const { data: projectsData, loading, error } = useProjects()
  const deleteProject = useDeleteProject()

  // Filter projects based on search and status
  const filteredProjects = Array.isArray(projectsData)
    ? projectsData.filter((project: any) => {
        const matchesSearch = project.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                             project.description?.toLowerCase().includes(searchTerm.toLowerCase())
        const matchesStatus = !statusFilter || project.status === statusFilter
        return matchesSearch && matchesStatus
      })
    : []

  const handleDelete = async (id: string) => {
    if (window.confirm(t('confirmDelete', 'Are you sure you want to delete this project?'))) {
      try {
        await deleteProject.mutate(id)
        // Refresh data or show success message
      } catch (error) {
        console.error('Failed to delete project:', error)
      }
    }
  }

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">{t('projects')}</h1>
        <Link href="/projects/create">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            {t('createProject', 'Create Project')}
          </Button>
        </Link>
      </div>

      {/* Filters */}
      <Card className="p-4 mb-6">
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1">
            <div className="relative">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <Input
                placeholder={t('searchProjects', 'Search projects...')}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-gray-400" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">{t('allStatuses', 'All Statuses')}</option>
              <option value="planning">Planning</option>
              <option value="active">Active</option>
              <option value="on-hold">On Hold</option>
              <option value="completed">Completed</option>
            </select>
          </div>
        </div>
      </Card>

      {/* Projects List */}
      {loading ? (
        <div className="flex justify-center py-8">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      ) : error ? (
        <Alert variant="destructive">
          {t('failedToLoadProjects', 'Failed to load projects')}: {error}
        </Alert>
      ) : (
        <Card>
          <Table>
            <thead>
              <tr>
                <th className="text-left">{t('name', 'Name')}</th>
                <th className="text-left">{t('description', 'Description')}</th>
                <th className="text-left">{t('status', 'Status')}</th>
                <th className="text-left">{t('progress', 'Progress')}</th>
                <th className="text-left">{t('actions', 'Actions')}</th>
              </tr>
            </thead>
            <tbody>
              {filteredProjects.map((project: any) => (
                <tr key={project.id}>
                  <td className="font-medium">{project.name}</td>
                  <td className="text-gray-600 max-w-xs truncate">{project.description}</td>
                  <td>
                    <Badge variant={
                      project.status === 'completed' ? 'default' :
                      project.status === 'active' ? 'secondary' :
                      'outline'
                    }>
                      {project.status}
                    </Badge>
                  </td>
                  <td>
                    <div className="flex items-center space-x-2">
                      <Progress value={project.progress || 0} className="w-20" />
                      <span className="text-sm">{project.progress || 0}%</span>
                    </div>
                  </td>
                  <td>
                    <div className="flex items-center space-x-2">
                      <Link href={`/projects/${project.id}`}>
                        <Button variant="outline" size="sm">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </Link>
                      <Link href={`/projects/${project.id}/edit`}>
                        <Button variant="outline" size="sm">
                          <Edit className="h-4 w-4" />
                        </Button>
                      </Link>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleDelete(project.id)}
                        disabled={deleteProject.loading}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
          {filteredProjects.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              {t('noProjectsFound', 'No projects found')}
            </div>
          )}
        </Card>
      )}
    </div>
  )
}
