import React from 'react'
import { useFormContext } from 'react-hook-form'

interface ValidationProps {
  name: string
  children: (error?: string) => React.ReactNode
}

export const Validation: React.FC<ValidationProps> = ({ name, children }) => {
  const {
    formState: { errors },
  } = useFormContext()

  const error = errors[name]?.message as string

  return <>{children(error)}</>
}
