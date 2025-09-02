import { useState, useEffect } from 'react'
import { apiClient } from './api'

// GitHub data types
interface GitHubCommit {
  id: string
  message: string
  author: string
  date: string
  sha: string
}

interface GitHubPullRequest {
  id: number
  title: string
  state: 'open' | 'closed'
  author: string
  createdAt: string
  url: string
}

interface GitHubIssue {
  id: number
  title: string
  state: 'open' | 'closed'
  author: string
  createdAt: string
  url: string
}

interface GitHubData {
  commits: GitHubCommit[]
  pullRequests: GitHubPullRequest[]
  issues: GitHubIssue[]
}

interface UseApiState<T> {
  data: T | null
  loading: boolean
  error: string | null
}

export function useApi<T>(
  endpoint: string,
  options: {
    method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'
    body?: any
    dependencies?: any[]
    enabled?: boolean
  } = {}
) {
  const {
    method = 'GET',
    body,
    dependencies = [],
    enabled = true,
  } = options

  const [state, setState] = useState<UseApiState<T>>({
    data: null,
    loading: false,
    error: null,
  })

  useEffect(() => {
    if (!enabled) return

    const fetchData = async () => {
      setState(prev => ({ ...prev, loading: true, error: null }))

      try {
        let response
        switch (method) {
          case 'GET':
            response = await apiClient.get<T>(endpoint)
            break
          case 'POST':
            response = await apiClient.post<T>(endpoint, body)
            break
          case 'PUT':
            response = await apiClient.put<T>(endpoint, body)
            break
          case 'PATCH':
            response = await apiClient.patch<T>(endpoint, body)
            break
          case 'DELETE':
            response = await apiClient.delete<T>(endpoint)
            break
          default:
            throw new Error(`Unsupported method: ${method}`)
        }

        setState({
          data: response.data,
          loading: false,
          error: null,
        })
      } catch (error) {
        setState({
          data: null,
          loading: false,
          error: error instanceof Error ? error.message : 'An error occurred',
        })
      }
    }

    fetchData()
  }, [endpoint, method, body, enabled, ...dependencies])

  return state
}

// Specific hooks for common operations
export function useProjects() {
  return useApi('/projects')
}

export function useProject(id: string) {
  return useApi(`/projects/${id}`, { enabled: !!id })
}

export function useTasks(projectId?: string) {
  const endpoint = projectId ? `/projects/${projectId}/tasks` : '/tasks'
  return useApi(endpoint)
}

export function useTask(id: string) {
  return useApi(`/tasks/${id}`, { enabled: !!id })
}

export function useResources() {
  return useApi('/resources')
}

export function useUsers() {
  return useApi('/users')
}

export function useDashboardStats() {
  return useApi('/dashboard/stats')
}

// Mutation hooks
export function useCreateProject() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.post('/projects', data)
      setState({
        data: response.data,
        loading: false,
        error: null,
      })
      return response
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error.message : 'An error occurred',
      })
      throw error
    }
  }

  return { ...state, mutate }
}

export function useCreateTask() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.post('/tasks', data)
      setState({
        data: response.data,
        loading: false,
        error: null,
      })
      return response
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error.message : 'An error occurred',
      })
      throw error
    }
  }

  return { ...state, mutate }
}

export function useUpdateProject(id: string) {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.put(`/projects/${id}`, data)
      setState({
        data: response.data,
        loading: false,
        error: null,
      })
      return response
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error.message : 'An error occurred',
      })
      throw error
    }
  }

  return { ...state, mutate }
}

export function useUpdateTask(id: string) {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.put(`/tasks/${id}`, data)
      setState({
        data: response.data,
        loading: false,
        error: null,
      })
      return response
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error.message : 'An error occurred',
      })
      throw error
    }
  }

  return { ...state, mutate }
}

export function useDeleteProject() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (id: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.delete(`/projects/${id}`)
      setState({
        data: response.data,
        loading: false,
        error: null,
      })
      return response
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error.message : 'An error occurred',
      })
      throw error
    }
  }

  return { ...state, mutate }
}

// Real-time updates hook (WebSocket/SSE)
export function useRealtimeUpdates(endpoint: string) {
  const [data, setData] = useState<any>(null)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    // For now, implement polling as fallback
    // In production, this would use WebSocket or SSE
    const pollData = async () => {
      try {
        const response = await apiClient.get(endpoint)
        setData(response.data)
        setConnected(true)
      } catch (error) {
        setConnected(false)
        console.error('Realtime update failed:', error)
      }
    }

    pollData()
    const interval = setInterval(pollData, 30000) // Poll every 30 seconds

    return () => clearInterval(interval)
  }, [endpoint])

  return { data, connected }
}

// GitHub integration hook
export function useGitHubData() {
  return useApi<GitHubData>('/github/integration')
}
