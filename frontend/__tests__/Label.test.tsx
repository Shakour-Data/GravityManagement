import React from 'react'
import { render, screen } from '@testing-library/react'
import { Label } from '../components/ui/label'

describe('Label Component', () => {
  test('renders with children', () => {
    render(<Label>Username</Label>)
    const label = screen.getByText('Username')
    expect(label).toBeInTheDocument()
    expect(label.tagName).toBe('LABEL')
  })

  test('applies custom className', () => {
    render(<Label className="custom-class">Email</Label>)
    const label = screen.getByText('Email')
    expect(label).toHaveClass('custom-class')
    expect(label).toHaveClass('block') // Should still have default classes
  })

  test('forwards props to label element', () => {
    render(<Label htmlFor="email-input" data-testid="email-label">Email</Label>)
    const label = screen.getByTestId('email-label')
    expect(label).toHaveAttribute('for', 'email-input')
  })

  test('has correct default styling', () => {
    render(<Label>Name</Label>)
    const label = screen.getByText('Name')
    expect(label).toHaveClass('block', 'text-sm', 'font-medium', 'text-gray-700')
  })

  test('renders different children types', () => {
    render(<Label><span>Complex</span> Label</Label>)
    expect(screen.getByText('Complex')).toBeInTheDocument()
    expect(screen.getByText('Label')).toBeInTheDocument()
  })

  test('supports id attribute', () => {
    render(<Label id="name-label">Name</Label>)
    const label = screen.getByText('Name')
    expect(label).toHaveAttribute('id', 'name-label')
  })

  test('has correct displayName', () => {
    expect(Label.displayName).toBe('Label')
  })
})
