import React from 'react'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
  className?: string
}

export const Card: React.FC<CardProps> = ({ children, className = '', ...props }) => {
  return (
    <div
      className={`bg-white rounded-md shadow-sm border border-gray-200 p-4 ${className}`}
      {...props}
    >
      {children}
    </div>
  )
}
