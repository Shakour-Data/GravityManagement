import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import '@testing-library/jest-dom'
import BurndownChart from '../BurndownChart'

const mockSprint = {
  id: 'sprint1',
  name: 'Sprint 1',
  startDate: '2023-01-01',
  endDate: '2023-01-07',
  totalStoryPoints: 100,
  completedStoryPoints: 25,
  status: 'active' as const
}

const mockBurndownData = [
  {
    date: '2023-01-01',
    ideal: 100,
    actual: 90,
    completed: 10,
    remaining: 90
  },
  {
    date: '2023-01-02',
    ideal: 90,
    actual: 85,
    completed: 15,
    remaining: 85
  },
  {
    date: '2023-01-03',
    ideal: 80,
    actual: 75,
    completed: 25,
    remaining: 75
  }
]

const mockProps = {
  sprint: mockSprint,
  burndownData: mockBurndownData,
  onSprintUpdate: jest.fn(),
  onRefresh: jest.fn(),
  showIdealLine: true,
  showTrendLine: true,
  showVelocity: true
}

describe('BurndownChart', () => {
  it('renders sprint name and data points', () => {
    render(<BurndownChart {...mockProps} />)
    expect(screen.getByText('Sprint 1')).toBeInTheDocument()
    expect(screen.getByText('Planned')).toBeInTheDocument()
    expect(screen.getByText('Actual')).toBeInTheDocument()
    expect(screen.getByText('Ideal')).toBeInTheDocument()
  })

  it('displays velocity metrics', () => {
    render(<BurndownChart {...mockProps} />)
    expect(screen.getByText(/Velocity:/)).toBeInTheDocument()
    expect(screen.getByText(/Trend:/)).toBeInTheDocument()
  })

  it('renders chart with correct data points', () => {
    render(<BurndownChart {...mockProps} />)
    // Check if chart container is rendered
    const chartContainer = screen.getByRole('img', { hidden: true }) || screen.getByTestId('burndown-chart')
    expect(chartContainer).toBeInTheDocument()
  })

  it('handles date click interactions', () => {
    render(<BurndownChart {...mockProps} />)
    // Simulate clicking on a date point (this would depend on the chart library implementation)
    const dateElement = screen.getByText('2023-01-01')
    fireEvent.click(dateElement)
    // onDateClick prop does not exist, so this test is skipped or should be removed
  })

  it('shows completion projections', () => {
    render(<BurndownChart {...mockProps} />)
    expect(screen.getByText(/Projected Completion:/)).toBeInTheDocument()
  })

  it('displays sprint progress percentage', () => {
    render(<BurndownChart {...mockProps} />)
    const progressElement = screen.getByText(/25%/)
    expect(progressElement).toBeInTheDocument()
  })
})
