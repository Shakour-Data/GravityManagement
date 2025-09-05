import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { CustomWidget } from '../CustomWidget';

describe('CustomWidget', () => {
  test('renders the component with initial widgets', () => {
    render(<CustomWidget />);
    expect(screen.getByText('Custom Widgets')).toBeInTheDocument();
    expect(screen.getByText('Add Widget')).toBeInTheDocument();
    expect(screen.getByText('Custom Chart')).toBeInTheDocument();
    expect(screen.getByText('Metrics')).toBeInTheDocument();
  });

  test('adds a new widget when Add Widget button is clicked', () => {
    render(<CustomWidget />);
    const addButton = screen.getByText('Add Widget');
    fireEvent.click(addButton);
    expect(screen.getByText('New Widget 3')).toBeInTheDocument();
  });

  test('removes a widget when remove button is clicked', () => {
    render(<CustomWidget />);
    const removeButton = screen.getAllByLabelText(/Remove/)[0];
    fireEvent.click(removeButton);
    expect(screen.queryByText('Custom Chart')).not.toBeInTheDocument();
  });
});
