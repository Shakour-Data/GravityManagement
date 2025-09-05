import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { AdvancedSearch } from '../AdvancedSearch';

describe('AdvancedSearch', () => {
  const mockOnSearch = jest.fn();

  beforeEach(() => {
    mockOnSearch.mockClear();
  });

  test('renders the component with basic search', () => {
    render(<AdvancedSearch onSearch={mockOnSearch} />);
    expect(screen.getByText('Advanced Search')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Search projects, tasks, resources...')).toBeInTheDocument();
  });

  test('toggles filters visibility', () => {
    render(<AdvancedSearch onSearch={mockOnSearch} />);
    const toggleButton = screen.getByText('Show Filters');
    fireEvent.click(toggleButton);
    expect(screen.getByText('Hide Filters')).toBeInTheDocument();
    expect(screen.getByText('Entity')).toBeInTheDocument();
  });

  test('calls onSearch with correct filters', () => {
    render(<AdvancedSearch onSearch={mockOnSearch} />);
    const searchButton = screen.getByText('Search');
    fireEvent.click(searchButton);
    expect(mockOnSearch).toHaveBeenCalledWith({
      query: '',
      entity: 'all',
      status: '',
      priority: '',
      dateFrom: '',
      dateTo: '',
    });
  });

  test('updates query on input change', () => {
    render(<AdvancedSearch onSearch={mockOnSearch} />);
    const input = screen.getByPlaceholderText('Search projects, tasks, resources...');
    fireEvent.change(input, { target: { value: 'test query' } });
    const searchButton = screen.getByText('Search');
    fireEvent.click(searchButton);
    expect(mockOnSearch).toHaveBeenCalledWith({
      query: 'test query',
      entity: 'all',
      status: '',
      priority: '',
      dateFrom: '',
      dateTo: '',
    });
  });

  test('clears filters', () => {
    render(<AdvancedSearch onSearch={mockOnSearch} />);
    const input = screen.getByPlaceholderText('Search projects, tasks, resources...');
    fireEvent.change(input, { target: { value: 'test' } });
    const clearButton = screen.getByText('Clear Filters');
    fireEvent.click(clearButton);
    const searchButton = screen.getByText('Search');
    fireEvent.click(searchButton);
    expect(mockOnSearch).toHaveBeenCalledWith({
      query: '',
      entity: 'all',
      status: '',
      priority: '',
      dateFrom: '',
      dateTo: '',
    });
  });
});
