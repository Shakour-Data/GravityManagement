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

export function useResource(id: string) {
  return useApi(`/resources/${id}`, { enabled: !!id })
}

export function useCreateResource() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.post('/resources', data)
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

export function useUpdateResource(id: string) {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.put(`/resources/${id}`, data)
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

export function useDeleteResource() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (id: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.delete(`/resources/${id}`)
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

export function useUsers() {
  return useApi('/users')
}

interface DashboardStats {
  totalProjects: number
  activeTasks: number
  teamMembers: number
  upcomingDeadlines: number
}

export function useDashboardStats() {
  return useApi<DashboardStats>('/dashboard/stats')
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
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let ws: WebSocket | null = null
    let reconnectTimeout: NodeJS.Timeout | null = null
    const maxReconnectAttempts = 5
    let reconnectAttempts = 0

    const connect = () => {
      if (reconnectAttempts >= maxReconnectAttempts) {
        setError('Max reconnection attempts reached')
        return
      }

      const wsUrl = `${process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:8000'}${endpoint}`
      ws = new WebSocket(wsUrl)

      ws.onopen = () => {
        setConnected(true)
        setError(null)
        reconnectAttempts = 0
        console.log('WebSocket connected')
      }

      ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data)
          setData(message)
        } catch (err) {
          console.error('Failed to parse WebSocket message:', err)
        }
      }

      ws.onclose = (event) => {
        setConnected(false)
        console.log('WebSocket disconnected:', event.code, event.reason)

        if (event.code !== 1000) { // Not a normal closure
          reconnectAttempts++
          reconnectTimeout = setTimeout(connect, 2000 * reconnectAttempts) // Exponential backoff
        }
      }

      ws.onerror = (event) => {
        setError('WebSocket error')
        console.error('WebSocket error:', event)
      }
    }

    connect()

    return () => {
      if (ws) {
        ws.close(1000, 'Component unmounting')
      }
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout)
      }
    }
  }, [endpoint])

  return { data, connected, error }
}

// GitHub integration hook
export function useGitHubData() {
  return useApi<GitHubData>('/github/integration')
}

// Rules hooks
export function useRules() {
  return useApi('/rules')
}

export function useRule(id: string) {
  return useApi(`/rules/${id}`, { enabled: !!id })
}

export function useCreateRule() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.post('/rules', data)
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

export function useUpdateRule(id: string) {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (data: any) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.put(`/rules/${id}`, data)
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

export function useDeleteRule() {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (id: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.delete(`/rules/${id}`)
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

export function useTestRule(id: string) {
  const [state, setState] = useState<UseApiState<any>>({
    data: null,
    loading: false,
    error: null,
  })

  const mutate = async (ruleId: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }))

    try {
      const response = await apiClient.post(`/rules/${ruleId}/test`)
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
