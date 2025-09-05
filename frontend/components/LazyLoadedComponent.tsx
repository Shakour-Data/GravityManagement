import React from 'react';

const LazyLoadedComponent: React.FC = () => {
  return (
    <div>
      <h2>This component is lazy loaded!</h2>
      <p>Content of the lazy loaded component.</p>
    </div>
  );
};

export default LazyLoadedComponent;
