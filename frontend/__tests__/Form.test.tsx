import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { z } from 'zod'
import { Form } from '../components/forms/Form'
import { FormField } from '../components/forms/FormField'

describe('Form and FormField components', () => {
  test('renders form and submits data', async () => {
    const onSubmit = jest.fn()
    const schema = z.object({
      testField: z.string().min(1, 'Required'),
    })

    render(
      <Form onSubmit={onSubmit} schema={schema}>
        <FormField name="testField" label="Test Field" required>
          <input data-testid="input" />
        </FormField>
        <button type="submit">Submit</button>
      </Form>
    )

    const input = screen.getByTestId('input')
    fireEvent.change(input, { target: { value: 'test value' } })
    fireEvent.click(screen.getByText('Submit'))

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalled()
    })
  })

  test('shows required error message', async () => {
    const onSubmit = jest.fn()
    const schema = z.object({
      testField: z.string().min(1, 'Required'),
    })

    render(
      <Form onSubmit={onSubmit} schema={schema}>
        <FormField name="testField" label="Test Field" required>
          <input data-testid="input" />
        </FormField>
        <button type="submit">Submit</button>
      </Form>
    )

    fireEvent.click(screen.getByText('Submit'))

    const errorMessage = await screen.findByText('Required')
    expect(errorMessage).toBeInTheDocument()
  })
})
