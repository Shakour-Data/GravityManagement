import React from 'react'
import { render, screen } from '@testing-library/react'
import { Badge } from '../components/ui/badge'

describe('Badge Component', () => {
  test('renders with default props', () => {
    render(<Badge>Default</Badge>)
    const badge = screen.getByText('Default')
    expect(badge).toBeInTheDocument()
    expect(badge.tagName).toBe('SPAN')
    expect(badge).toHaveClass('inline-flex', 'items-center', 'rounded-full', 'px-2.5', 'py-0.5', 'text-xs', 'font-medium')
  })

  test('renders with default variant', () => {
    render(<Badge variant="default">Default</Badge>)
    const badge = screen.getByText('Default')
    expect(badge).toHaveClass('bg-primary', 'text-primary-foreground')
  })

  test('renders with secondary variant', () => {
    render(<Badge variant="secondary">Secondary</Badge>)
    const badge = screen.getByText('Secondary')
    expect(badge).toHaveClass('bg-secondary', 'text-secondary-foreground')
  })

  test('renders with destructive variant', () => {
    render(<Badge variant="destructive">Destructive</Badge>)
    const badge = screen.getByText('Destructive')
    expect(badge).toHaveClass('bg-destructive', 'text-destructive-foreground')
  })

  test('renders with outline variant', () => {
    render(<Badge variant="outline">Outline</Badge>)
    const badge = screen.getByText('Outline')
    expect(badge).toHaveClass('border', 'border-input', 'bg-background')
  })

  test('renders with default size', () => {
    render(<Badge size="default">Default Size</Badge>)
    const badge = screen.getByText('Default Size')
    expect(badge).toHaveClass('h-5')
  })

  test('renders with small size', () => {
    render(<Badge size="sm">Small</Badge>)
    const badge = screen.getByText('Small')
    expect(badge).toHaveClass('h-4', 'text-[10px]')
  })

  test('applies custom className', () => {
    render(<Badge className="custom-class">Custom</Badge>)
    const badge = screen.getByText('Custom')
    expect(badge).toHaveClass('custom-class')
  })

  test('forwards props to span element', () => {
    render(<Badge data-testid="badge-element" id="test-badge">Test</Badge>)
    const badge = screen.getByTestId('badge-element')
    expect(badge).toHaveAttribute('id', 'test-badge')
  })

  test('supports different children types', () => {
    render(<Badge><span>Icon</span> Text</Badge>)
    expect(screen.getByText('Icon')).toBeInTheDocument()
    expect(screen.getByText('Text')).toBeInTheDocument()
  })

  test('has correct displayName', () => {
    expect(Badge.displayName).toBe('Badge')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLSpanElement>()
    render(<Badge ref={ref}>Ref Test</Badge>)
    expect(ref.current).toBeInstanceOf(HTMLSpanElement)
    expect(ref.current?.textContent).toBe('Ref Test')
  })
})
