import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import '@testing-library/jest-dom/extend-expect'
import { Input } from '../input'

describe('Input', () => {
  it('renders with default props', () => {
    render(<Input placeholder="Enter text" />)
    const input = screen.getByPlaceholderText('Enter text')
    expect(input).toBeInTheDocument()
    expect(input).toHaveAttribute('type', 'text')
  })

  it('handles text input', async () => {
    const user = userEvent.setup()
    render(<Input placeholder="Enter text" />)
    const input = screen.getByPlaceholderText('Enter text')

    await user.type(input, 'Hello World')
    expect(input).toHaveValue('Hello World')
  })

  it('supports different input types', () => {
    const { rerender } = render(<Input type="email" placeholder="Enter email" />)
    let input = screen.getByPlaceholderText('Enter email')
    expect(input).toHaveAttribute('type', 'email')

    rerender(<Input type="password" placeholder="Enter password" />)
    input = screen.getByPlaceholderText('Enter password')
    expect(input).toHaveAttribute('type', 'password')

    rerender(<Input type="number" placeholder="Enter number" />)
    input = screen.getByPlaceholderText('Enter number')
    expect(input).toHaveAttribute('type', 'number')
  })

  it('is disabled when disabled prop is true', () => {
    render(<Input disabled placeholder="Disabled input" />)
    const input = screen.getByPlaceholderText('Disabled input')
    expect(input).toBeDisabled()
  })

  it('shows required indicator', () => {
    render(<Input required placeholder="Required field" />)
    const input = screen.getByPlaceholderText('Required field')
    expect(input).toBeRequired()
  })

  it('applies custom className', () => {
    render(<Input className="custom-class" placeholder="Custom input" />)
    const input = screen.getByPlaceholderText('Custom input')
    expect(input).toHaveClass('custom-class')
  })

  it('handles onChange events', async () => {
    const user = userEvent.setup()
    const handleChange = jest.fn()
    render(<Input onChange={handleChange} placeholder="Test input" />)
    const input = screen.getByPlaceholderText('Test input')

    await user.type(input, 'a')
    expect(handleChange).toHaveBeenCalled()
  })

  it('supports maxLength attribute', () => {
    render(<Input maxLength={10} placeholder="Limited input" />)
    const input = screen.getByPlaceholderText('Limited input')
    expect(input).toHaveAttribute('maxLength', '10')
  })

  it('supports pattern attribute', () => {
    const pattern = '[A-Za-z]+'
    render(<Input pattern={pattern} placeholder="Pattern input" />)
    const input = screen.getByPlaceholderText('Pattern input')
    expect(input).toHaveAttribute('pattern', pattern)
  })
})
