'use client'

import React from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { Badge } from '@/components/ui/badge'
import { Calendar, Users, Folder, CheckCircle } from 'lucide-react'

export default function DashboardPage() {
  const { t } = useTranslation('common')

  // Mock data - replace with real data from API
  const stats = [
    { title: 'Total Projects', value: '12', icon: Folder, color: 'text-blue-600' },
    { title: 'Active Tasks', value: '45', icon: CheckCircle, color: 'text-green-600' },
    { title: 'Team Members', value: '8', icon: Users, color: 'text-purple-600' },
    { title: 'Upcoming Deadlines', value: '3', icon: Calendar, color: 'text-red-600' },
  ]

  const recentProjects = [
    { name: 'Project Alpha', progress: 75, status: 'In Progress' },
    { name: 'Project Beta', progress: 90, status: 'Review' },
    { name: 'Project Gamma', progress: 30, status: 'Planning' },
  ]

  const recentTasks = [
    { name: 'Design new UI', priority: 'High', status: 'In Progress' },
    { name: 'Implement API', priority: 'Medium', status: 'Done' },
    { name: 'Write documentation', priority: 'Low', status: 'Todo' },
  ]

  return (
    <div className="p-6">
      <h1 className="text-3xl font-bold mb-6">{t('dashboard')}</h1>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {stats.map((stat, index) => (
          <Card key={index} className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">{stat.title}</p>
                <p className="text-2xl font-bold">{stat.value}</p>
              </div>
              <stat.icon className={`h-8 w-8 ${stat.color}`} />
            </div>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Projects */}
        <Card className="p-6">
          <h2 className="text-xl font-semibold mb-4">{t('projects')}</h2>
          <div className="space-y-4">
            {recentProjects.map((project, index) => (
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
            {recentTasks.map((task, index) => (
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
