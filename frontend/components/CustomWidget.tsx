import React, { useState } from 'react';

interface Widget {
  id: string;
  title: string;
  content: React.ReactNode;
}

const defaultWidgets: Widget[] = [
  {
    id: 'widget1',
    title: 'Custom Chart',
    content: <div>Chart Placeholder</div>,
  },
  {
    id: 'widget2',
    title: 'Metrics',
    content: <div>Metrics Placeholder</div>,
  },
];

export const CustomWidget: React.FC = () => {
  const [widgets, setWidgets] = useState<Widget[]>(defaultWidgets);

  const removeWidget = (id: string) => {
    setWidgets(widgets.filter(widget => widget.id !== id));
  };

  const addWidget = () => {
    const newWidget: Widget = {
      id: `widget${widgets.length + 1}`,
      title: `New Widget ${widgets.length + 1}`,
      content: <div>New Widget Content</div>,
    };
    setWidgets([...widgets, newWidget]);
  };

  return (
    <div>
      <h3 className="text-lg font-semibold mb-4">Custom Widgets</h3>
      <button
        onClick={addWidget}
        className="mb-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Add Widget
      </button>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {widgets.map(widget => (
          <div key={widget.id} className="border rounded p-4 shadow">
            <div className="flex justify-between items-center mb-2">
              <h4 className="font-medium">{widget.title}</h4>
              <button
                onClick={() => removeWidget(widget.id)}
                className="text-red-500 hover:text-red-700"
                aria-label={`Remove ${widget.title}`}
              >
                &times;
              </button>
            </div>
            <div>{widget.content}</div>
          </div>
        ))}
      </div>
    </div>
  );
};
