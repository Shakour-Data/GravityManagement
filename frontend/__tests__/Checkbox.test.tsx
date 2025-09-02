import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Checkbox } from '../components/ui/checkbox'

describe('Checkbox Component', () => {
  test('renders with default props', () => {
    render(<Checkbox />)
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).toBeInTheDocument()
    expect(checkbox).toHaveClass('h-4', 'w-4', 'shrink-0', 'rounded-sm', 'border', 'border-primary')
  })

  test('handles checked state', () => {
    render(<Checkbox checked />)
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).toBeChecked()
  })

  test('handles unchecked state', () => {
    render(<Checkbox checked={false} />)
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).not.toBeChecked()
  })

  test('shows check icon when checked', () => {
    render(<Checkbox checked />)
    // The check icon should be present when checked
    const checkIcon = document.querySelector('svg')
    expect(checkIcon).toBeInTheDocument()
  })

  test('does not show check icon when unchecked', () => {
    render(<Checkbox checked={false} />)
    // The check icon should not be present when unchecked
    const checkIcon = document.querySelector('svg')
    expect(checkIcon).not.toBeInTheDocument()
  })

  test('handles user interaction', async () => {
    const user = userEvent.setup()
    const handleChange = jest.fn()
    render(<Checkbox onCheckedChange={handleChange} />)

    const checkbox = screen.getByRole('checkbox')
    await user.click(checkbox)

    expect(handleChange).toHaveBeenCalledWith(true)
  })

  test('handles disabled state', () => {
    render(<Checkbox disabled />)
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).toBeDisabled()
    expect(checkbox).toHaveClass('disabled:cursor-not-allowed', 'disabled:opacity-50')
  })

  test('applies custom className', () => {
    render(<Checkbox className="custom-class" />)
    const checkbox = screen.getByRole('checkbox')
    expect(checkbox).toHaveClass('custom-class')
  })

  test('forwards props correctly', () => {
    render(<Checkbox data-testid="test-checkbox" id="checkbox-id" />)
    const checkbox = screen.getByTestId('test-checkbox')
    expect(checkbox).toHaveAttribute('id', 'checkbox-id')
  })

  test('supports controlled component', () => {
    const { rerender } = render(<Checkbox checked={true} />)
    let checkbox = screen.getByRole('checkbox')
    expect(checkbox).toBeChecked()

    rerender(<Checkbox checked={false} />)
    checkbox = screen.getByRole('checkbox')
    expect(checkbox).not.toBeChecked()
  })

  test('has correct displayName', () => {
    expect(Checkbox.displayName).toBe('Checkbox')
  })
})
