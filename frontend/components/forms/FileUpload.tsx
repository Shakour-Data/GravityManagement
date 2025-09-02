import React, { useState } from 'react'
import { useFormContext } from 'react-hook-form'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Upload } from 'lucide-react'

interface FileUploadProps {
  name: string
  label: string
  accept?: string
  required?: boolean
  className?: string
}

export const FileUpload: React.FC<FileUploadProps> = ({
  name,
  label,
  accept = '*',
  required = false,
  className = '',
}) => {
  const [fileName, setFileName] = useState<string>('')
  const {
    register,
    setValue,
    formState: { errors },
  } = useFormContext()

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (file) {
      setFileName(file.name)
      setValue(name, file)
    }
  }

  return (
    <div className={`space-y-2 ${className}`}>
      <Label htmlFor={name}>
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </Label>
      <div className="flex items-center space-x-2">
        <input
          id={name}
          type="file"
          accept={accept}
          className="hidden"
          {...register(name, {
            onChange: handleFileChange,
          })}
        />
        <Button
          type="button"
          variant="outline"
          onClick={() => document.getElementById(name)?.click()}
          className="flex items-center space-x-2"
        >
          <Upload className="h-4 w-4" />
          <span>Choose File</span>
        </Button>
        {fileName && <span className="text-sm text-gray-600">{fileName}</span>}
      </div>
      {errors[name] && (
        <p className="text-sm text-red-500">
          {errors[name]?.message as string}
        </p>
      )}
    </div>
  )
}
