/**
 * AdvancedSearch Component
 *
 * A comprehensive search component that allows users to perform advanced searches
 * across projects, tasks, resources, and rules with filtering, saving, and loading capabilities.
 *
 * @param {AdvancedSearchProps} props - The props for the component
 * @param {function} props.onSearch - Callback function called when search is executed
 * @param {function} [props.onClose] - Optional callback function called when close button is clicked
 *
 * @example
 * <AdvancedSearch
 *   onSearch={(filters) => console.log('Search filters:', filters)}
 *   onClose={() => console.log('Search closed')}
 * />
 */
"use client";

import React, { useState } from 'react';
import { Search, Filter, X } from 'lucide-react';
import { sanitizeInput, validateRequired } from '@/lib/sanitize';

interface SearchFilters {
  query: string;
  entity: string;
  status: string;
  priority: string;
  dateFrom: string;
  dateTo: string;
}

interface SavedSearch {
  id: string;
  name: string;
  filters: SearchFilters;
}

interface AdvancedSearchProps {
  onSearch: (filters: SearchFilters) => void;
  onClose?: () => void;
}

export const AdvancedSearch: React.FC<AdvancedSearchProps> = ({ onSearch, onClose }) => {
  const [filters, setFilters] = useState<SearchFilters>({
    query: '',
    entity: 'all',
    status: '',
    priority: '',
    dateFrom: '',
    dateTo: '',
  });

  const [isExpanded, setIsExpanded] = useState(false);
  const [savedSearches, setSavedSearches] = useState<SavedSearch[]>([]);
  const [saveName, setSaveName] = useState('');

  const handleInputChange = (field: keyof SearchFilters, value: string) => {
    setFilters(prev => ({ ...prev, [field]: value }));
  };

  const handleSearch = () => {
    onSearch(filters);
  };

  const clearFilters = () => {
    setFilters({
      query: '',
      entity: 'all',
      status: '',
      priority: '',
      dateFrom: '',
      dateTo: '',
    });
  };

  const saveSearch = () => {
    if (saveName) {
      const newSaved: SavedSearch = {
        id: crypto.randomUUID(),
        name: saveName,
        filters: { ...filters }
      };
      setSavedSearches(prev => [...prev, newSaved]);
      setSaveName('');
    }
  };

  const loadSearch = (saved: SavedSearch) => {
    setFilters(saved.filters);
  };

  const deleteSavedSearch = (id: string) => {
    setSavedSearches(prev => prev.filter(s => s.id !== id));
  };

  return (
    <div className="bg-white border rounded-lg shadow-sm p-4">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-2">
          <Search className="h-5 w-5 text-gray-500" />
          <h3 className="text-lg font-semibold">Advanced Search</h3>
        </div>
        {onClose && (
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            <X className="h-5 w-5" />
          </button>
        )}
      </div>

      <div className="space-y-4">
        {/* Basic Search */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Search Query
          </label>
          <input
            type="text"
            value={filters.query}
            onChange={(e) => handleInputChange('query', e.target.value)}
            placeholder="Search projects, tasks, resources..."
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        {/* Expandable Filters */}
        <div>
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="flex items-center space-x-2 text-blue-600 hover:text-blue-800"
          >
            <Filter className="h-4 w-4" />
            <span>{isExpanded ? 'Hide Filters' : 'Show Filters'}</span>
          </button>
        </div>

        {isExpanded && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Entity
              </label>
              <select
                value={filters.entity}
                onChange={(e) => handleInputChange('entity', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="all">All</option>
                <option value="projects">Projects</option>
                <option value="tasks">Tasks</option>
                <option value="resources">Resources</option>
                <option value="rules">Rules</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <select
                value={filters.status}
                onChange={(e) => handleInputChange('status', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Any Status</option>
                <option value="active">Active</option>
                <option value="completed">Completed</option>
                <option value="pending">Pending</option>
                <option value="on-hold">On Hold</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Priority
              </label>
              <select
                value={filters.priority}
                onChange={(e) => handleInputChange('priority', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Any Priority</option>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Date From
              </label>
              <input
                type="date"
                value={filters.dateFrom}
                onChange={(e) => handleInputChange('dateFrom', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Date To
              </label>
              <input
                type="date"
                value={filters.dateTo}
                onChange={(e) => handleInputChange('dateTo', e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        )}

        {/* Save Search */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Save Current Search
          </label>
          <div className="flex space-x-2">
            <input
              type="text"
              value={saveName}
              onChange={(e) => setSaveName(e.target.value)}
              placeholder="Enter search name"
              className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              onClick={saveSearch}
              className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
            >
              Save
            </button>
          </div>
        </div>

        {/* Saved Searches */}
        {savedSearches.length > 0 && (
          <div>
            <h4 className="text-lg font-semibold mb-2">Saved Searches</h4>
            <div className="space-y-2">
              {savedSearches.map((saved) => (
                <div key={saved.id} className="flex items-center justify-between p-2 border rounded">
                  <span>{saved.name}</span>
                  <div className="flex space-x-2">
                    <button
                      onClick={() => loadSearch(saved)}
                      className="px-2 py-1 bg-blue-500 text-white rounded text-sm"
                    >
                      Load
                    </button>
                    <button
                      onClick={() => deleteSavedSearch(saved.id)}
                      className="px-2 py-1 bg-red-500 text-white rounded text-sm"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex space-x-2">
          <button
            onClick={handleSearch}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            Search
          </button>
          <button
            onClick={clearFilters}
            className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500"
          >
            Clear Filters
          </button>
        </div>
      </div>
    </div>
  );
};
