import React from 'react'
import { useTranslation } from 'next-i18next'
import { Card } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { GitBranch, GitPullRequest, AlertCircle, ExternalLink } from 'lucide-react'

interface GitHubData {
  commits: Array<{
    id: string
    message: string
    author: string
    date: string
    sha: string
  }>
  pullRequests: Array<{
    id: number
    title: string
    state: 'open' | 'closed'
    author: string
    createdAt: string
    url: string
  }>
  issues: Array<{
    id: number
    title: string
    state: 'open' | 'closed'
    author: string
    createdAt: string
    url: string
  }>
}

interface GitHubIntegrationProps {
  data: GitHubData | null
  loading?: boolean
  error?: string | null
}

export function GitHubIntegration({ data, loading, error }: GitHubIntegrationProps) {
  const { t } = useTranslation('common')

  if (loading) {
    return (
      <Card className="p-6">
        <div className="flex items-center justify-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      </Card>
    )
  }

  if (error) {
    return (
      <Card className="p-6">
        <div className="text-center text-red-500">
          <AlertCircle className="h-8 w-8 mx-auto mb-2" />
          <p>{t('github.error', 'Failed to load GitHub data')}</p>
          <p className="text-sm text-gray-500 mt-1">{error}</p>
        </div>
      </Card>
    )
  }

  if (!data) {
    return (
      <Card className="p-6">
        <div className="text-center text-gray-500">
          <GitBranch className="h-8 w-8 mx-auto mb-2" />
          <p>{t('github.noData', 'No GitHub data available')}</p>
        </div>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      {/* Recent Commits */}
      <Card className="p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold flex items-center">
            <GitBranch className="h-5 w-5 mr-2" />
            {t('github.recentCommits', 'Recent Commits')}
          </h3>
          <Badge variant="secondary">
            {data.commits.length}
          </Badge>
        </div>
        <div className="space-y-3">
          {data.commits.slice(0, 5).map((commit) => (
            <div key={commit.id} className="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
              <GitBranch className="h-4 w-4 text-green-600 mt-1 flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{commit.message}</p>
                <div className="flex items-center space-x-2 mt-1">
                  <span className="text-xs text-gray-600">{commit.author}</span>
                  <span className="text-xs text-gray-400">•</span>
                  <span className="text-xs text-gray-600">
                    {new Date(commit.date).toLocaleDateString()}
                  </span>
                </div>
                <p className="text-xs text-gray-500 font-mono mt-1">
                  {commit.sha.substring(0, 7)}
                </p>
              </div>
            </div>
          ))}
        </div>
        {data.commits.length > 5 && (
          <Button variant="outline" className="w-full mt-4">
            {t('github.viewAllCommits', 'View All Commits')}
          </Button>
        )}
      </Card>

      {/* Pull Requests */}
      <Card className="p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold flex items-center">
            <GitPullRequest className="h-5 w-5 mr-2" />
            {t('github.pullRequests', 'Pull Requests')}
          </h3>
          <div className="flex space-x-2">
            <Badge variant="secondary">
              {data.pullRequests.filter(pr => pr.state === 'open').length} {t('github.open', 'Open')}
            </Badge>
            <Badge variant="outline">
              {data.pullRequests.filter(pr => pr.state === 'closed').length} {t('github.closed', 'Closed')}
            </Badge>
          </div>
        </div>
        <div className="space-y-3">
          {data.pullRequests.slice(0, 3).map((pr) => (
            <div key={pr.id} className="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
              <GitPullRequest className={`h-4 w-4 mt-1 flex-shrink-0 ${
                pr.state === 'open' ? 'text-green-600' : 'text-red-600'
              }`} />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{pr.title}</p>
                <div className="flex items-center space-x-2 mt-1">
                  <span className="text-xs text-gray-600">{pr.author}</span>
                  <span className="text-xs text-gray-400">•</span>
                  <span className="text-xs text-gray-600">
                    {new Date(pr.createdAt).toLocaleDateString()}
                  </span>
                  <Badge variant={pr.state === 'open' ? 'default' : 'secondary'} className="text-xs">
                    {pr.state}
                  </Badge>
                </div>
              </div>
              <Button variant="ghost" size="sm" asChild>
                <a href={pr.url} target="_blank" rel="noopener noreferrer">
                  <ExternalLink className="h-4 w-4" />
                </a>
              </Button>
            </div>
          ))}
        </div>
        {data.pullRequests.length > 3 && (
          <Button variant="outline" className="w-full mt-4">
            {t('github.viewAllPRs', 'View All Pull Requests')}
          </Button>
        )}
      </Card>

      {/* Issues */}
      <Card className="p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold flex items-center">
            <AlertCircle className="h-5 w-5 mr-2" />
            {t('github.issues', 'Issues')}
          </h3>
          <div className="flex space-x-2">
            <Badge variant="secondary">
              {data.issues.filter(issue => issue.state === 'open').length} {t('github.open', 'Open')}
            </Badge>
            <Badge variant="outline">
              {data.issues.filter(issue => issue.state === 'closed').length} {t('github.closed', 'Closed')}
            </Badge>
          </div>
        </div>
        <div className="space-y-3">
          {data.issues.slice(0, 3).map((issue) => (
            <div key={issue.id} className="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
              <AlertCircle className={`h-4 w-4 mt-1 flex-shrink-0 ${
                issue.state === 'open' ? 'text-blue-600' : 'text-gray-600'
              }`} />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{issue.title}</p>
                <div className="flex items-center space-x-2 mt-1">
                  <span className="text-xs text-gray-600">{issue.author}</span>
                  <span className="text-xs text-gray-400">•</span>
                  <span className="text-xs text-gray-600">
                    {new Date(issue.createdAt).toLocaleDateString()}
                  </span>
                  <Badge variant={issue.state === 'open' ? 'default' : 'secondary'} className="text-xs">
                    {issue.state}
                  </Badge>
                </div>
              </div>
              <Button variant="ghost" size="sm" asChild>
                <a href={issue.url} target="_blank" rel="noopener noreferrer">
                  <ExternalLink className="h-4 w-4" />
                </a>
              </Button>
            </div>
          ))}
        </div>
        {data.issues.length > 3 && (
          <Button variant="outline" className="w-full mt-4">
            {t('github.viewAllIssues', 'View All Issues')}
          </Button>
        )}
      </Card>
    </div>
  )
}

export default GitHubIntegration
