import React from 'react'
import { useFormContext } from 'react-hook-form'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'

interface FormFieldProps {
  name: string
  label: string
  type?: string
  placeholder?: string
  required?: boolean
  className?: string
  children?: React.ReactNode
}

export const FormField: React.FC<FormFieldProps> = ({
  name,
  label,
  type = 'text',
  placeholder,
  required = false,
  className = '',
  children,
}) => {
  const {
    register,
    formState: { errors },
  } = useFormContext()

  return (
    <div className={`space-y-2 ${className}`}>
      <Label htmlFor={name}>
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </Label>
      {children ? (
        React.cloneElement(children as React.ReactElement, {
          ...register(name),
          className: `${(children as React.ReactElement).props.className || ''} ${errors[name] ? 'border-red-500' : ''}`,
        })
      ) : (
        <Input
          id={name}
          type={type}
          placeholder={placeholder}
          {...register(name)}
          className={errors[name] ? 'border-red-500' : ''}
        />
      )}
      {errors[name] && (
        <p className="text-sm text-red-500">
          {errors[name]?.message as string}
        </p>
      )}
    </div>
  )
}
