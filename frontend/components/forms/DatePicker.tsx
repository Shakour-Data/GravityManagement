import React from 'react'
import { useFormContext } from 'react-hook-form'
import { Label } from '@/components/ui/label'

interface DatePickerProps {
  name: string
  label: string
  required?: boolean
  className?: string
}

export const DatePicker: React.FC<DatePickerProps> = ({
  name,
  label,
  required = false,
  className = '',
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
      <input
        id={name}
        type="date"
        {...register(name)}
        className={`w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
          errors[name] ? 'border-red-500' : ''
        }`}
      />
      {errors[name] && (
        <p className="text-sm text-red-500">
          {errors[name]?.message as string}
        </p>
      )}
    </div>
  )
}
