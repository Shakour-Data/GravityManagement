import React from 'react'
import { render, screen, waitFor } from '@testing-library/react'
import { Avatar, AvatarImage, AvatarFallback } from '../components/ui/avatar'

describe('Avatar Component', () => {
  test('renders with default props', () => {
    render(<Avatar />)
    const avatar = document.querySelector('[data-radix-avatar-root]')
    expect(avatar).toBeInTheDocument()
    expect(avatar).toHaveClass('relative', 'flex', 'h-10', 'w-10', 'shrink-0', 'overflow-hidden', 'rounded-full')
  })

  test('applies custom className', () => {
    render(<Avatar className="custom-avatar" />)
    const avatar = document.querySelector('[data-radix-avatar-root]')
    expect(avatar).toHaveClass('custom-avatar')
  })

  test('forwards props correctly', () => {
    render(<Avatar data-testid="test-avatar" id="avatar-id" />)
    const avatar = screen.getByTestId('test-avatar')
    expect(avatar).toHaveAttribute('id', 'avatar-id')
  })

  test('has correct displayName', () => {
    expect(Avatar.displayName).toBe('Avatar')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLDivElement>()
    render(<Avatar ref={ref} />)
    expect(ref.current).toBeInstanceOf(HTMLDivElement)
  })
})

describe('AvatarImage Component', () => {
  test('renders with src prop', () => {
    render(<AvatarImage src="https://example.com/avatar.jpg" alt="User Avatar" />)
    const image = document.querySelector('[data-radix-avatar-image]')
    expect(image).toBeInTheDocument()
    expect(image).toHaveAttribute('src', 'https://example.com/avatar.jpg')
    expect(image).toHaveAttribute('alt', 'User Avatar')
  })

  test('applies custom className', () => {
    render(<AvatarImage src="test.jpg" className="custom-image" />)
    const image = document.querySelector('[data-radix-avatar-image]')
    expect(image).toHaveClass('custom-image')
  })

  test('forwards props correctly', () => {
    render(<AvatarImage src="test.jpg" data-testid="test-image" id="image-id" />)
    const image = screen.getByTestId('test-image')
    expect(image).toHaveAttribute('id', 'image-id')
  })

  test('has correct displayName', () => {
    expect(AvatarImage.displayName).toBe('AvatarImage')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLImageElement>()
    render(<AvatarImage src="test.jpg" ref={ref} />)
    expect(ref.current).toBeInstanceOf(HTMLImageElement)
  })
})

describe('AvatarFallback Component', () => {
  test('renders with children', () => {
    render(<AvatarFallback>JD</AvatarFallback>)
    const fallback = document.querySelector('[data-radix-avatar-fallback]')
    expect(fallback).toBeInTheDocument()
    expect(fallback).toHaveClass('flex', 'h-full', 'w-full', 'items-center', 'justify-center', 'rounded-full', 'bg-muted')
    expect(fallback).toHaveTextContent('JD')
  })

  test('applies custom className', () => {
    render(<AvatarFallback className="custom-fallback">AB</AvatarFallback>)
    const fallback = document.querySelector('[data-radix-avatar-fallback]')
    expect(fallback).toHaveClass('custom-fallback')
  })

  test('forwards props correctly', () => {
    render(<AvatarFallback data-testid="test-fallback" id="fallback-id">XY</AvatarFallback>)
    const fallback = screen.getByTestId('test-fallback')
    expect(fallback).toHaveAttribute('id', 'fallback-id')
  })

  test('has correct displayName', () => {
    expect(AvatarFallback.displayName).toBe('AvatarFallback')
  })

  test('uses forwardRef correctly', () => {
    const ref = React.createRef<HTMLDivElement>()
    render(<AvatarFallback ref={ref}>ZZ</AvatarFallback>)
    expect(ref.current).toBeInstanceOf(HTMLDivElement)
  })
})

describe('Avatar Integration', () => {
  test('renders complete avatar with image and fallback', () => {
    render(
      <Avatar>
        <AvatarImage src="https://example.com/avatar.jpg" alt="User" />
        <AvatarFallback>JD</AvatarFallback>
      </Avatar>
    )

    const avatar = document.querySelector('[data-radix-avatar-root]')
    const image = document.querySelector('[data-radix-avatar-image]')
    const fallback = document.querySelector('[data-radix-avatar-fallback]')

    expect(avatar).toBeInTheDocument()
    expect(image).toBeInTheDocument()
    expect(fallback).toBeInTheDocument()
    expect(image).toHaveAttribute('src', 'https://example.com/avatar.jpg')
    expect(fallback).toHaveTextContent('JD')
  })

  test('fallback is visible when image fails to load', async () => {
    render(
      <Avatar>
        <AvatarImage src="invalid-image-url.jpg" alt="User" />
        <AvatarFallback>FB</AvatarFallback>
      </Avatar>
    )

    const image = document.querySelector('[data-radix-avatar-image]')
    const fallback = document.querySelector('[data-radix-avatar-fallback]')

    // Initially, both should be present
    expect(image).toBeInTheDocument()
    expect(fallback).toBeInTheDocument()

    // Simulate image error
    if (image) {
      image.dispatchEvent(new Event('error'))
    }

    // The fallback should still be visible (Radix handles this internally)
    expect(fallback).toBeInTheDocument()
  })

  test('renders fallback when no image is provided', () => {
    render(
      <Avatar>
        <AvatarFallback>AB</AvatarFallback>
      </Avatar>
    )

    const avatar = document.querySelector('[data-radix-avatar-root]')
    const fallback = document.querySelector('[data-radix-avatar-fallback]')

    expect(avatar).toBeInTheDocument()
    expect(fallback).toBeInTheDocument()
    expect(fallback).toHaveTextContent('AB')
  })
})
