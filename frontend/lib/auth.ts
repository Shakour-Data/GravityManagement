import React from 'react'
import { apiClient } from './api'

export interface User {
  id: string
  name: string
  email: string
  role?: string
}

export interface AuthState {
  user: User | null
  isAuthenticated: boolean
  isLoading: boolean
}

class AuthService {
  private authState: AuthState = {
    user: null,
    isAuthenticated: false,
    isLoading: true,
  }

  private listeners: ((state: AuthState) => void)[] = []

  constructor() {
    this.initializeAuth()
  }

  private async initializeAuth() {
    try {
      const token = this.getToken()
      if (token) {
        // Verify token with backend
        const response = await apiClient.get('/auth/me')
        this.authState = {
          user: response.data,
          isAuthenticated: true,
          isLoading: false,
        }
      } else {
        this.authState.isLoading = false
      }
    } catch (error) {
      this.logout()
    } finally {
      this.notifyListeners()
    }
  }

  async login(credentials: { email: string; password: string }) {
    try {
      this.authState.isLoading = true
      this.notifyListeners()

      const response = await apiClient.login(credentials)

      this.authState = {
        user: response.data.user,
        isAuthenticated: true,
        isLoading: false,
      }

      this.notifyListeners()
      return response
    } catch (error) {
      this.authState.isLoading = false
      this.notifyListeners()
      throw error
    }
  }

  async register(userData: { name: string; email: string; password: string }) {
    try {
      this.authState.isLoading = true
      this.notifyListeners()

      const response = await apiClient.register(userData)

      this.authState.isLoading = false
      this.notifyListeners()
      return response
    } catch (error) {
      this.authState.isLoading = false
      this.notifyListeners()
      throw error
    }
  }

  async logout() {
    try {
      await apiClient.logout()
    } catch (error) {
      console.error('Logout error:', error)
    } finally {
      this.clearAuth()
    }
  }

  private clearAuth() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('authToken')
    }

    this.authState = {
      user: null,
      isAuthenticated: false,
      isLoading: false,
    }

    this.notifyListeners()
  }

  getToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('authToken')
    }
    return null
  }

  getAuthState(): AuthState {
    return { ...this.authState }
  }

  subscribe(listener: (state: AuthState) => void): () => void {
    this.listeners.push(listener)
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener)
    }
  }

  private notifyListeners() {
    this.listeners.forEach(listener => listener(this.authState))
  }
}

// Create and export singleton instance
export const authService = new AuthService()

// React hook for using auth state
export function useAuth() {
  const [state, setState] = React.useState(authService.getAuthState())

  React.useEffect(() => {
    const unsubscribe = authService.subscribe(setState)
    return unsubscribe
  }, [])

  return {
    ...state,
    login: authService.login.bind(authService),
    register: authService.register.bind(authService),
    logout: authService.logout.bind(authService),
  }
}

// Utility functions
export function isAuthenticated(): boolean {
  return authService.getAuthState().isAuthenticated
}

export function getCurrentUser(): User | null {
  return authService.getAuthState().user
}

export function requireAuth(): void {
  if (typeof window !== 'undefined' && !isAuthenticated()) {
    window.location.href = '/auth/login'
  }
}
