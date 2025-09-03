'use client'

import { useEffect, useRef, useState } from 'react'

interface LazyLoadProps {
  children: React.ReactNode
  fallback?: React.ReactNode
  rootMargin?: string
  threshold?: number
}

export default function LazyLoad({
  children,
  fallback = <div className="animate-pulse bg-gray-200 rounded h-32"></div>,
  rootMargin = '50px',
  threshold = 0.1
}: LazyLoadProps) {
  const [isVisible, setIsVisible] = useState(false)
  const [hasLoaded, setHasLoaded] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !hasLoaded) {
          setIsVisible(true)
          setHasLoaded(true)
        }
      },
      {
        rootMargin,
        threshold,
      }
    )

    if (ref.current) {
      observer.observe(ref.current)
    }

    return () => {
      if (ref.current) {
        observer.unobserve(ref.current)
      }
    }
  }, [hasLoaded, rootMargin, threshold])

  return (
    <div ref={ref}>
      {isVisible ? children : fallback}
    </div>
  )
}

// Lazy load wrapper for components
export function lazyLoadComponent<T extends React.ComponentType<any>>(
  importFunc: () => Promise<{ default: T }>,
  fallback?: React.ReactNode
) {
  return function LazyComponent(props: React.ComponentProps<T>) {
    const [Component, setComponent] = useState<T | null>(null)
    const [isLoading, setIsLoading] = useState(true)

    useEffect(() => {
      importFunc().then((module) => {
        setComponent(() => module.default)
        setIsLoading(false)
      })
    }, [])

    if (isLoading) {
      return fallback || <div className="animate-pulse bg-gray-200 rounded h-32"></div>
    }

    return Component ? <Component {...props} /> : null
  }
}
