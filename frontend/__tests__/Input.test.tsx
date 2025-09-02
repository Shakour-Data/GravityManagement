import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Input } from '../components/ui/input'

describe('Input Component', () => {
  test('renders with default props', () => {
    render(<Input />)
    const input = screen.getByRole('textbox')
    expect(input).toBeInTheDocument()
    expect(input).toHaveClass('w-full', 'px-3', 'py-2', 'border', 'border-gray-300', 'rounded-md')
  })

  test('applies custom className', () => {
    render(<Input className="custom-class" />)
    const input = screen.getByRole('textbox')
    expect(input).toHaveClass('custom-class')
    expect(input).toHaveClass('w-full') // Should still have default classes
  })

  test('forwards props to input element', () => {
    render(<Input type="email" placeholder="Enter email" data-testid="email-input" />)
    const input = screen.getByTestId('email-input')
    expect(input).toHaveAttribute('type', 'email')
    expect(input).toHaveAttribute('placeholder', 'Enter email')
  })

  test('handles user input', async () => {
    const user = userEvent.setup()
    render(<Input />)
    const input = screen.getByRole('textbox')

    await user.type(input, 'test input')
    expect(input).toHaveValue('test input')
  })

  test('supports different input types', () => {
    const { rerender } = render(<Input type="password" />)
    expect(screen.getByDisplayValue('')).toHaveAttribute('type', 'password')

    rerender(<Input type="number" />)
    expect(screen.getByDisplayValue('')).toHaveAttribute('type', 'number')
  })

  test('has correct focus styles', async () => {
    const user = userEvent.setup()
    render(<Input />)
    const input = screen.getByRole('textbox')

    await user.click(input)
    expect(input).toHaveFocus()
    // Note: focus styles are applied via CSS, so we can't easily test the exact classes without more setup
  })

  test('is disabled when disabled prop is true', () => {
    render(<Input disabled />)
    const input = screen.getByRole('textbox')
    expect(input).toBeDisabled()
  })

  test('has correct displayName', () => {
    expect(Input.displayName).toBe('Input')
  })
})
