import React, { FormHTMLAttributes } from 'react'
import { useForm, FormProvider } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

interface FormProps extends FormHTMLAttributes<HTMLFormElement> {
  onSubmit: (data: any) => void
  schema?: z.ZodSchema
  defaultValues?: Record<string, any>
  children: React.ReactNode
}

export const Form: React.FC<FormProps> = ({
  onSubmit,
  schema,
  defaultValues,
  children,
  ...props
}) => {
  const methods = useForm({
    resolver: schema ? zodResolver(schema) : undefined,
    defaultValues,
  })

  const handleSubmit = methods.handleSubmit(onSubmit)

  return (
    <FormProvider {...methods}>
      <form onSubmit={handleSubmit} {...props}>
        {children}
      </form>
    </FormProvider>
  )
}
