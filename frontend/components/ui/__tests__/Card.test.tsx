import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom/extend-expect'
import { Card } from '../card'

describe('Card', () => {
  it('renders with default props', () => {
    render(<Card>Card content</Card>)
    const card = screen.getByText('Card content')
    expect(card).toBeInTheDocument()
  })

  it('applies custom className', () => {
    render(<Card className="custom-card">Content</Card>)
    const card = screen.getByText('Content').parentElement
    expect(card).toHaveClass('custom-card')
  })

  it('renders with children elements', () => {
    render(
      <Card>
        <h2>Project Dashboard</h2>
        <p>Overview of project metrics</p>
        <div>
          <p>Project statistics and charts</p>
        </div>
        <button>View Details</button>
      </Card>
    )

    expect(screen.getByText('Project Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Overview of project metrics')).toBeInTheDocument()
    expect(screen.getByText('Project statistics and charts')).toBeInTheDocument()
    expect(screen.getByText('View Details')).toBeInTheDocument()
  })

  it('applies default styling classes', () => {
    render(<Card>Test content</Card>)
    const card = screen.getByText('Test content').parentElement
    expect(card).toHaveClass('bg-white', 'rounded-md', 'shadow-sm', 'border', 'border-gray-200', 'p-4')
  })

  it('passes through additional props', () => {
    render(<Card data-testid="custom-card">Content</Card>)
    const card = screen.getByTestId('custom-card')
    expect(card).toBeInTheDocument()
  })

  it('handles empty content gracefully', () => {
    render(<Card>{''}</Card>)
    const card = document.querySelector('.bg-white')
    expect(card).toBeInTheDocument()
  })
})
