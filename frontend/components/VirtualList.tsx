import React from 'react';
import { FixedSizeList as List } from 'react-window';

interface VirtualListProps {
  items: any[];
  itemHeight: number;
  height: number;
  width: number;
  renderItem: (item: any, index: number) => React.ReactNode;
}

export const VirtualList: React.FC<VirtualListProps> = ({
  items,
  itemHeight,
  height,
  width,
  renderItem,
}) => {
  return (
    <List
      height={height}
      itemCount={items.length}
      itemSize={itemHeight}
      width={width}
    >
      {({ index, style }) => (
        <div style={style}>
          {renderItem(items[index], index)}
        </div>
      )}
    </List>
  );
};
