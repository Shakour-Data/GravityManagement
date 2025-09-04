import React from 'react'
import { render, screen } from '@testing-library/react'
import '@testing-library/jest-dom'
import ResourceUtilizationHeatmap from '../ResourceUtilizationHeatmap'

const mockData = [
  {
    resourceId: 'res1',
    resourceName: 'John Doe',
    resourceType: 'human' as const,
    date: '2023-01-01',
    utilization: 50,
    capacity: 8,
    allocated: 4,
    available: 4
  },
  {
    resourceId: 'res1',
    resourceName: 'John Doe',
    resourceType: 'human' as const,
    date: '2023-01-02',
    utilization: 70,
    capacity: 8,
    allocated: 5.6,
    available: 2.4
  },
  {
    resourceId: 'res1',
    resourceName: 'John Doe',
    resourceType: 'human' as const,
    date: '2023-01-03',
    utilization: 30,
    capacity: 8,
    allocated: 2.4,
    available: 5.6
  }
]

const mockProps = {
  data: mockData,
  startDate: new Date('2023-01-01'),
  endDate: new Date('2023-01-31'),
  onResourceFilter: jest.fn(),
  onDateRangeChange: jest.fn(),
  onCellClick: jest.fn()
}

describe('ResourceUtilizationHeatmap', () => {
  it('renders heatmap cells', () => {
    render(<ResourceUtilizationHeatmap {...mockProps} />)
    mockData.forEach(item => {
      expect(screen.getByText(new Date(item.date).getDate().toString())).toBeInTheDocument()
    })
  })

  it('calls onCellClick when a cell is clicked', () => {
    render(<ResourceUtilizationHeatmap {...mockProps} />)
    const cell = screen.getByText('1')
    cell.click()
    expect(mockProps.onCellClick).toHaveBeenCalled()
  })
})
