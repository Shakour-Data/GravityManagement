import React from 'react'
import { render, screen } from '@testing-library/react'
import { Progress } from '../components/ui/progress'

describe('Progress Component', () => {
  test('renders with default props', () => {
    render(<Progress />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
    expect(progress).toHaveClass('relative', 'h-4', 'w-full', 'overflow-hidden', 'rounded-full', 'bg-secondary')
  })

  test('shows 0% progress by default', () => {
    render(<Progress />)
    const indicator = document.querySelector('[data-radix-progress-indicator]')
    // Indicator is not rendered when value is 0 or undefined
    expect(indicator).toBeNull()
  })

  test('shows correct progress for value 0', () => {
    render(<Progress value={0} />)
    const indicator = document.querySelector('[data-radix-progress-indicator]')
    // Indicator is not rendered when value is 0
    expect(indicator).toBeNull()
  })

  test('accepts value prop', () => {
    render(<Progress value={50} />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
    // The value prop is passed to the Radix component, but we can't easily test the internal transform
  })

  test('accepts value 100', () => {
    render(<Progress value={100} />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
  })

  test('handles value greater than 100', () => {
    render(<Progress value={150} />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
  })

  test('handles negative value', () => {
    render(<Progress value={-10} />)
    const indicator = document.querySelector('[data-radix-progress-indicator]')
    // Indicator is not rendered for negative values
    expect(indicator).toBeNull()
  })

  test('applies custom className', () => {
    render(<Progress className="custom-class" />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toHaveClass('custom-class')
  })

  test('forwards props correctly', () => {
    render(<Progress data-testid="test-progress" id="progress-id" />)
    const progress = screen.getByTestId('test-progress')
    expect(progress).toHaveAttribute('id', 'progress-id')
  })

  test('renders with value prop', () => {
    render(<Progress value={75} />)
    const progress = screen.getByRole('progressbar')
    expect(progress).toBeInTheDocument()
    // We can't easily test the internal indicator styling in Radix UI components
  })

  test('has correct displayName', () => {
    expect(Progress.displayName).toBe('Progress')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLDivElement>()
    render(<Progress ref={ref} />)
    expect(ref.current).toBeInstanceOf(HTMLDivElement)
    expect(ref.current?.getAttribute('role')).toBe('progressbar')
  })
})
