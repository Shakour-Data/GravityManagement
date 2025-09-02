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
import { Loader2, Plus, Search, Edit, Eye, Filter } from 'lucide-react'
import { useTasks } from '@/lib/hooks'

export default function TasksPage() {
  const { t } = useTranslation('common')
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [priorityFilter, setPriorityFilter] = useState('')

  // Fetch tasks
  const { data: tasksData, loading, error } = useTasks()

  // Filter tasks based on search, status, and priority
  const filteredTasks = Array.isArray(tasksData)
    ? tasksData.filter((task: any) => {
        const matchesSearch = task.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                             task.description?.toLowerCase().includes(searchTerm.toLowerCase())
        const matchesStatus = !statusFilter || task.status === statusFilter
        const matchesPriority = !priorityFilter || task.priority === priorityFilter
        return matchesSearch && matchesStatus && matchesPriority
      })
    : []

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">{t('tasks')}</h1>
        <Link href="/tasks/create">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            {t('createTask', 'Create Task')}
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
                placeholder={t('searchTasks', 'Search tasks...')}
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
              <option value="todo">To Do</option>
              <option value="in_progress">In Progress</option>
              <option value="done">Done</option>
            </select>
            <select
              value={priorityFilter}
              onChange={(e) => setPriorityFilter(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">{t('allPriorities', 'All Priorities')}</option>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </select>
          </div>
        </div>
      </Card>

      {/* Tasks List */}
      {loading ? (
        <div className="flex justify-center py-8">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      ) : error ? (
        <Alert variant="destructive">
          {t('failedToLoadTasks', 'Failed to load tasks')}: {error}
        </Alert>
      ) : (
        <Card>
          <Table>
            <thead>
              <tr>
                <th className="text-left">{t('name', 'Name')}</th>
                <th className="text-left">{t('description', 'Description')}</th>
                <th className="text-left">{t('status', 'Status')}</th>
                <th className="text-left">{t('priority', 'Priority')}</th>
                <th className="text-left">{t('dueDate', 'Due Date')}</th>
                <th className="text-left">{t('progress', 'Progress')}</th>
                <th className="text-left">{t('actions', 'Actions')}</th>
              </tr>
            </thead>
            <tbody>
              {filteredTasks.map((task: any) => (
                <tr key={task.id}>
                  <td className="font-medium">{task.name}</td>
                  <td className="text-gray-600 max-w-xs truncate">{task.description}</td>
                  <td>
                    <Badge variant={
                      task.status === 'done' ? 'default' :
                      task.status === 'in_progress' ? 'secondary' :
                      'outline'
                    }>
                      {task.status}
                    </Badge>
                  </td>
                  <td>
                    <Badge variant={
                      task.priority === 'high' ? 'destructive' :
                      task.priority === 'medium' ? 'default' :
                      'secondary'
                    }>
                      {task.priority}
                    </Badge>
                  </td>
                  <td>{task.dueDate ? new Date(task.dueDate).toLocaleDateString() : t('notSet', 'Not set')}</td>
                  <td>
                    <div className="flex items-center space-x-2">
                      <Progress value={task.progress || 0} className="w-20" />
                      <span className="text-sm">{task.progress || 0}%</span>
                    </div>
                  </td>
                  <td>
                    <div className="flex items-center space-x-2">
                      <Link href={`/tasks/${task.id}`}>
                        <Button variant="outline" size="sm">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </Link>
                      <Link href={`/tasks/${task.id}/edit`}>
                        <Button variant="outline" size="sm">
                          <Edit className="h-4 w-4" />
                        </Button>
                      </Link>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
          {filteredTasks.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              {t('noTasksFound', 'No tasks found')}
            </div>
          )}
        </Card>
      )}
    </div>
  )
}
