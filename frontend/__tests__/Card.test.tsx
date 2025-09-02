import React from 'react'
import { render, screen } from '@testing-library/react'
import { Card } from '../components/ui/card'

describe('Card Component', () => {
  test('renders with children', () => {
    render(<Card>Card Content</Card>)
    const card = screen.getByText('Card Content')
    expect(card).toBeInTheDocument()
    expect(card.tagName).toBe('DIV')
  })

  test('applies custom className', () => {
    render(<Card className="custom-class">Content</Card>)
    const card = screen.getByText('Content')
    expect(card).toHaveClass('custom-class')
    expect(card).toHaveClass('bg-white') // Should still have default classes
  })

  test('forwards props to div element', () => {
    render(<Card data-testid="card-element" id="test-card">Test</Card>)
    const card = screen.getByTestId('card-element')
    expect(card).toHaveAttribute('id', 'test-card')
  })

  test('has correct default styling', () => {
    render(<Card>Content</Card>)
    const card = screen.getByText('Content')
    expect(card).toHaveClass('bg-white', 'rounded-md', 'shadow-sm', 'border', 'border-gray-200', 'p-4')
  })

  test('renders different children types', () => {
    render(
      <Card>
        <h2>Title</h2>
        <p>Description</p>
      </Card>
    )
    expect(screen.getByText('Title')).toBeInTheDocument()
    expect(screen.getByText('Description')).toBeInTheDocument()
  })

  test('supports role attribute', () => {
    render(<Card role="region">Region Content</Card>)
    const card = screen.getByRole('region')
    expect(card).toBeInTheDocument()
  })

  test('has correct displayName', () => {
    expect(Card.displayName).toBe('Card')
  })
})
