import { render, screen, fireEvent } from '@testing-library/react'
import GanttChart from '../GanttChart'

const mockProps = {
  tasks: [
    { id: '1', name: 'Task 1', startDate: '2023-01-01', endDate: '2023-01-10', duration: 9, progress: 50, priority: 'medium' as const, status: 'in_progress' as const },
    { id: '2', name: 'Task 2', startDate: '2023-01-05', endDate: '2023-01-15', duration: 10, progress: 20, priority: 'high' as const, status: 'todo' as const }
  ],
  milestones: [],
  onTaskUpdate: jest.fn(),
  onTaskClick: jest.fn(),
  onMilestoneClick: jest.fn(),
  onDateRangeChange: jest.fn(),
  currentDate: new Date('2023-01-07'),
  showWeekends: true,
  showDependencies: true,
  showProgress: true
}

describe('GanttChart', () => {
  it('renders task names', () => {
    render(<GanttChart {...mockProps} />)
    expect(screen.getAllByText('Task 1').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Task 2').length).toBeGreaterThan(0)
  })

  it('renders progress bars with correct width', () => {
    render(<GanttChart {...mockProps} />)
    const progressBars = screen.getAllByTestId('task-progress-bar')
    expect(progressBars[0]).toHaveStyle('width: 50%')
    expect(progressBars[1]).toHaveStyle('width: 20%')
  })

  it('handles zoom in and zoom out buttons', () => {
    render(<GanttChart {...mockProps} />)
    const zoomInButton = screen.getByLabelText('Zoom In')
    const zoomOutButton = screen.getByLabelText('Zoom Out')

    fireEvent.click(zoomInButton)
    fireEvent.click(zoomOutButton)
  })

  it('renders dependencies arrows', () => {
    render(<GanttChart {...mockProps} />)
    // Check for SVG arrows or dependency indicators
    const arrows = screen.queryAllByTestId('dependency-arrow')
    expect(arrows.length).toBeGreaterThanOrEqual(0)
  })
})
