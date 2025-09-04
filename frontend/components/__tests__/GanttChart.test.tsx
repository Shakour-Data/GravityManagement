import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import '@testing-library/jest-dom'
import GanttChart from '../GanttChart'

const mockTasks = [
  {
    id: 'task1',
    name: 'Task 1',
    startDate: '2023-01-01',
    endDate: '2023-01-05',
    duration: 5,
    progress: 50,
    priority: 'high' as const,
    status: 'in_progress' as const,
    dependencies: []
  },
  {
    id: 'task2',
    name: 'Task 2',
    startDate: '2023-01-06',
    endDate: '2023-01-10',
    duration: 5,
    progress: 20,
    priority: 'medium' as const,
    status: 'todo' as const,
    dependencies: ['task1']
  }
]

const mockMilestones = [
  {
    id: 'milestone1',
    name: 'Project Launch',
    date: '2023-01-15'
  }
]

const mockProps = {
  tasks: mockTasks,
  milestones: mockMilestones,
  onTaskUpdate: jest.fn(),
  onTaskClick: jest.fn(),
  onMilestoneClick: jest.fn(),
  onDateRangeChange: jest.fn()
}

describe('GanttChart', () => {
  it('renders task names', () => {
    render(<GanttChart {...mockProps} />)
    expect(screen.getByText('Task 1')).toBeInTheDocument()
    expect(screen.getByText('Task 2')).toBeInTheDocument()
  })

  it('renders progress bars with correct width', () => {
    render(<GanttChart {...mockProps} />)
    const progressBars = screen.getAllByRole('progressbar')
    expect(progressBars[0]).toHaveStyle('width: 50%')
    expect(progressBars[1]).toHaveStyle('width: 20%')
  })

  it('handles zoom in and zoom out buttons', () => {
    render(<GanttChart {...mockProps} />)
    const zoomInButton = screen.getByLabelText('Zoom In')
    const zoomOutButton = screen.getByLabelText('Zoom Out')

    fireEvent.click(zoomInButton)
    fireEvent.click(zoomOutButton)
    // Additional assertions can be added based on zoom state if exposed
  })

  it('renders dependencies arrows', () => {
    render(<GanttChart {...mockProps} />)
    // Check for SVG arrows or dependency indicators
    const arrows = screen.getAllByTestId('dependency-arrow')
    expect(arrows.length).toBeGreaterThan(0)
  })
})
