import React from 'react'
import { render, screen } from '@testing-library/react'
import { Alert, AlertTitle, AlertDescription } from '../components/ui/alert'

describe('Alert Component', () => {
  test('renders with default props', () => {
    render(<Alert>Alert content</Alert>)
    const alert = screen.getByRole('alert')
    expect(alert).toBeInTheDocument()
    expect(alert).toHaveClass('relative', 'w-full', 'rounded-lg', 'border', 'p-4', 'bg-background', 'text-foreground')
  })

  test('renders with destructive variant', () => {
    render(<Alert variant="destructive">Destructive alert</Alert>)
    const alert = screen.getByRole('alert')
    expect(alert).toBeInTheDocument()
    expect(alert).toHaveClass('border-destructive/50', 'text-destructive')
  })

  test('applies custom className', () => {
    render(<Alert className="custom-class">Alert content</Alert>)
    const alert = screen.getByRole('alert')
    expect(alert).toHaveClass('custom-class')
  })

  test('forwards props correctly', () => {
    render(<Alert data-testid="test-alert" id="alert-id">Alert content</Alert>)
    const alert = screen.getByTestId('test-alert')
    expect(alert).toHaveAttribute('id', 'alert-id')
  })

  test('has correct role attribute', () => {
    render(<Alert>Alert content</Alert>)
    const alert = screen.getByRole('alert')
    expect(alert).toHaveAttribute('role', 'alert')
  })

  test('renders children correctly', () => {
    render(<Alert>Test message</Alert>)
    expect(screen.getByText('Test message')).toBeInTheDocument()
  })

  test('has correct displayName', () => {
    expect(Alert.displayName).toBe('Alert')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLDivElement>()
    render(<Alert ref={ref}>Alert content</Alert>)
    expect(ref.current).toBeInstanceOf(HTMLDivElement)
    expect(ref.current?.getAttribute('role')).toBe('alert')
  })
})

describe('AlertTitle Component', () => {
  test('renders with default props', () => {
    render(<AlertTitle>Alert Title</AlertTitle>)
    const title = screen.getByRole('heading', { level: 5 })
    expect(title).toBeInTheDocument()
    expect(title).toHaveClass('mb-1', 'font-medium', 'leading-none', 'tracking-tight')
  })

  test('renders children correctly', () => {
    render(<AlertTitle>Test Title</AlertTitle>)
    expect(screen.getByText('Test Title')).toBeInTheDocument()
  })

  test('applies custom className', () => {
    render(<AlertTitle className="custom-title">Title</AlertTitle>)
    const title = screen.getByRole('heading', { level: 5 })
    expect(title).toHaveClass('custom-title')
  })

  test('forwards props correctly', () => {
    render(<AlertTitle data-testid="test-title" id="title-id">Title</AlertTitle>)
    const title = screen.getByTestId('test-title')
    expect(title).toHaveAttribute('id', 'title-id')
  })

  test('has correct displayName', () => {
    expect(AlertTitle.displayName).toBe('AlertTitle')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLHeadingElement>()
    render(<AlertTitle ref={ref}>Title</AlertTitle>)
    expect(ref.current).toBeInstanceOf(HTMLHeadingElement)
    expect(ref.current?.tagName).toBe('H5')
  })
})

describe('AlertDescription Component', () => {
  test('renders with default props', () => {
    render(<AlertDescription>Alert description</AlertDescription>)
    const description = screen.getByText('Alert description')
    expect(description).toBeInTheDocument()
    expect(description).toHaveClass('text-sm')
  })

  test('renders children correctly', () => {
    render(<AlertDescription>Test description</AlertDescription>)
    expect(screen.getByText('Test description')).toBeInTheDocument()
  })

  test('applies custom className', () => {
    render(<AlertDescription className="custom-desc">Description</AlertDescription>)
    const description = screen.getByText('Description')
    expect(description).toHaveClass('custom-desc')
  })

  test('forwards props correctly', () => {
    render(<AlertDescription data-testid="test-desc" id="desc-id">Description</AlertDescription>)
    const description = screen.getByTestId('test-desc')
    expect(description).toHaveAttribute('id', 'desc-id')
  })

  test('has correct displayName', () => {
    expect(AlertDescription.displayName).toBe('AlertDescription')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLDivElement>()
    render(<AlertDescription ref={ref}>Description</AlertDescription>)
    expect(ref.current).toBeInstanceOf(HTMLDivElement)
  })
})

describe('Alert Integration', () => {
  test('renders complete alert with title and description', () => {
    render(
      <Alert>
        <AlertTitle>Error Occurred</AlertTitle>
        <AlertDescription>
          Something went wrong. Please try again later.
        </AlertDescription>
      </Alert>
    )

    expect(screen.getByRole('alert')).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 5 })).toHaveTextContent('Error Occurred')
    expect(screen.getByText('Something went wrong. Please try again later.')).toBeInTheDocument()
  })

  test('renders destructive alert with title and description', () => {
    render(
      <Alert variant="destructive">
        <AlertTitle>Warning</AlertTitle>
        <AlertDescription>
          This action cannot be undone.
        </AlertDescription>
      </Alert>
    )

    const alert = screen.getByRole('alert')
    expect(alert).toHaveClass('border-destructive/50', 'text-destructive')
    expect(screen.getByRole('heading', { level: 5 })).toHaveTextContent('Warning')
    expect(screen.getByText('This action cannot be undone.')).toBeInTheDocument()
  })
})
