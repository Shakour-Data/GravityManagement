class ApiClient {
  private baseURL: string

  constructor(baseURL: string = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000') {
    this.baseURL = baseURL
  }

  private getAuthToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('authToken')
    }
    return null
  }

  private handleUnauthorized() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('authToken')
      window.location.href = '/auth/login'
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<{ data: T; status: number }> {
    const url = `${this.baseURL}${endpoint}`
    const token = this.getAuthToken()

    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers,
      },
      ...options,
    }

    try {
      const response = await fetch(url, config)
      const data = await response.json()

      if (!response.ok) {
        if (response.status === 401) {
          this.handleUnauthorized()
        }
        throw new Error(data.message || `HTTP error! status: ${response.status}`)
      }

      return { data, status: response.status }
    } catch (error) {
      console.error('API request failed:', error)
      throw error
    }
  }

  // Generic request methods
  async get<T = any>(endpoint: string): Promise<{ data: T; status: number }> {
    return this.request<T>(endpoint, { method: 'GET' })
  }

  async post<T = any>(endpoint: string, data?: any): Promise<{ data: T; status: number }> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  async put<T = any>(endpoint: string, data?: any): Promise<{ data: T; status: number }> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  async patch<T = any>(endpoint: string, data?: any): Promise<{ data: T; status: number }> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    })
  }

  async delete<T = any>(endpoint: string): Promise<{ data: T; status: number }> {
    return this.request<T>(endpoint, { method: 'DELETE' })
  }

  // Auth-specific methods
  async login(credentials: { email: string; password: string }) {
    const response = await this.post('/auth/login', credentials)
    if (response.data.token) {
      this.setAuthToken(response.data.token)
    }
    return response
  }

  async register(userData: { name: string; email: string; password: string }) {
    return this.post('/auth/register', userData)
  }

  async logout() {
    const response = await this.post('/auth/logout')
    this.removeAuthToken()
    return response
  }

  private setAuthToken(token: string) {
    if (typeof window !== 'undefined') {
      localStorage.setItem('authToken', token)
    }
  }

  private removeAuthToken() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('authToken')
    }
  }
}

// Create and export a singleton instance
export const apiClient = new ApiClient()

// Export types for TypeScript
export interface ApiResponse<T = any> {
  data: T
  message?: string
  status: number
}

export default apiClient
