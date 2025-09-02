'use client'

import React from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { Badge } from '@/components/ui/badge'
import { Alert } from '@/components/ui/alert'
import { Calendar, Users, Folder, CheckCircle, Loader2 } from 'lucide-react'
import { useDashboardStats, useProjects, useTasks } from '@/lib/hooks'

export default function DashboardPage() {
  const { t } = useTranslation('common')

  // Fetch data from API
  const { data: statsData, loading: statsLoading, error: statsError } = useDashboardStats()
  const { data: projectsData, loading: projectsLoading, error: projectsError } = useProjects()
  const { data: tasksData, loading: tasksLoading, error: tasksError } = useTasks()

  // Process stats data
  const stats = statsData ? [
    { title: 'Total Projects', value: statsData.totalProjects?.toString() || '0', icon: Folder, color: 'text-blue-600' },
    { title: 'Active Tasks', value: statsData.activeTasks?.toString() || '0', icon: CheckCircle, color: 'text-green-600' },
    { title: 'Team Members', value: statsData.teamMembers?.toString() || '0', icon: Users, color: 'text-purple-600' },
    { title: 'Upcoming Deadlines', value: statsData.upcomingDeadlines?.toString() || '0', icon: Calendar, color: 'text-red-600' },
  ] : []

  // Process recent projects (take first 3)
  const recentProjects = projectsData?.slice(0, 3).map(project => ({
    name: project.name,
    progress: project.progress || 0,
    status: project.status || 'Unknown'
  })) || []

  // Process recent tasks (take first 3)
  const recentTasks = tasksData?.slice(0, 3).map(task => ({
    name: task.name,
    priority: task.priority || 'Medium',
    status: task.status || 'Todo'
  })) || []

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">{t('dashboard')}</h1>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {statsLoading ? (
          <div className="col-span-full flex justify-center">
            <Loader2 className="h-8 w-8 animate-spin" />
          </div>
        ) : statsError ? (
          <div className="col-span-full">
            <Alert variant="destructive">
              Failed to load dashboard stats: {statsError}
            </Alert>
          </div>
        ) : (
          stats.map((stat, index) => (
            <Card key={index} className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                  <p className="text-2xl font-bold">{stat.value}</p>
                </div>
                <stat.icon className={`h-8 w-8 ${stat.color}`} />
              </div>
            </Card>
          ))
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Projects */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('projects')}</h2>
          <div className="space-y-4">
            {recentProjects.map((project: any, index: number) => (
              <div key={index} className="flex items-center justify-between">
                <div className="flex-1">
                  <p className="font-medium">{project.name}</p>
                  <Progress value={project.progress} className="mt-2" />
                  <p className="text-sm text-gray-600 mt-1">{project.progress}% complete</p>
                </div>
                <Badge variant={project.status === 'Done' ? 'default' : 'secondary'}>
                  {project.status}
                </Badge>
              </div>
            ))}
          </div>
          <Button className="mt-4 w-full" variant="outline">
            View All Projects
          </Button>
        </Card>

        {/* Recent Tasks */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('tasks')}</h2>
          <div className="space-y-4">
            {recentTasks.map((task: any, index: number) => (
              <div key={index} className="flex items-center justify-between">
                <div>
                  <p className="font-medium">{task.name}</p>
                  <div className="flex items-center space-x-2 mt-1">
                    <Badge
                      variant={
                        task.priority === 'High'
                          ? 'destructive'
                          : task.priority === 'Medium'
                          ? 'default'
                          : 'secondary'
                      }
                    >
                      {task.priority}
                    </Badge>
                    <Badge variant="outline">{task.status}</Badge>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <Button className="mt-4 w-full" variant="outline">
            View All Tasks
          </Button>
        </Card>
      </div>

      {/* Activity Feed */}
      <Card className="p-6 mt-6">
        <h2 className="text-xl font-semibold mb-4">Activity Feed</h2>
        <div className="space-y-4">
          <div className="flex items-start space-x-3">
            <div className="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
            <div>
              <p className="text-sm">
                <span className="font-medium">John Doe</span> completed task "Design new UI"
              </p>
              <p className="text-xs text-gray-500">2 hours ago</p>
            </div>
          </div>
          <div className="flex items-start space-x-3">
            <div className="w-2 h-2 bg-green-500 rounded-full mt-2"></div>
            <div>
              <p className="text-sm">
                <span className="font-medium">Jane Smith</span> created new project "Project Delta"
              </p>
              <p className="text-xs text-gray-500">4 hours ago</p>
            </div>
          </div>
          <div className="flex items-start space-x-3">
            <div className="w-2 h-2 bg-purple-500 rounded-full mt-2"></div>
            <div>
              <p className="text-sm">
                <span className="font-medium">Mike Johnson</span> updated task status
              </p>
              <p className="text-xs text-gray-500">6 hours ago</p>
            </div>
          </div>
        </div>
      </Card>
    </div>
  )
}
