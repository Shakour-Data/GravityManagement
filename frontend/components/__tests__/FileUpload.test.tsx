import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { FileUpload } from '../FileUpload';

describe('FileUpload', () => {
  const mockOnFilesUploaded = jest.fn();

  beforeEach(() => {
    mockOnFilesUploaded.mockClear();
  });

  test('renders the component with dropzone', () => {
    render(<FileUpload onFilesUploaded={mockOnFilesUploaded} />);
    expect(screen.getByText(/Drag & drop files here/)).toBeInTheDocument();
  });

  test('displays uploaded files', async () => {
    render(<FileUpload onFilesUploaded={mockOnFilesUploaded} />);

    const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
    const input = screen.getByLabelText(/file input/i);

    fireEvent.change(input, { target: { files: [file] } });

    await waitFor(() => {
      expect(screen.getByText('test.txt')).toBeInTheDocument();
    });

    expect(mockOnFilesUploaded).toHaveBeenCalledWith([file]);
  });

  test('removes file when remove button is clicked', async () => {
    render(<FileUpload onFilesUploaded={mockOnFilesUploaded} />);

    const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
    const input = screen.getByLabelText(/file input/i);

    fireEvent.change(input, { target: { files: [file] } });

    await waitFor(() => {
      expect(screen.getByText('test.txt')).toBeInTheDocument();
    });

    const removeButton = screen.getByLabelText(/Remove test.txt/);
    fireEvent.click(removeButton);

    await waitFor(() => {
      expect(screen.queryByText('test.txt')).not.toBeInTheDocument();
    });

    expect(mockOnFilesUploaded).toHaveBeenCalledWith([]);
  });

  test('respects maxFiles limit', async () => {
    render(<FileUpload onFilesUploaded={mockOnFilesUploaded} maxFiles={1} />);

    const file1 = new File(['content1'], 'file1.txt', { type: 'text/plain' });
    const file2 = new File(['content2'], 'file2.txt', { type: 'text/plain' });
    const input = screen.getByLabelText(/file input/i);

    fireEvent.change(input, { target: { files: [file1, file2] } });

    await waitFor(() => {
      expect(screen.getByText('file1.txt')).toBeInTheDocument();
      expect(screen.queryByText('file2.txt')).not.toBeInTheDocument();
    });
  });
});
