import { useRef } from 'react';
import { Group, Panel, Separator, useDefaultLayout } from 'react-resizable-panels';
import type { PanelImperativeHandle } from 'react-resizable-panels';
import { cn } from '@/lib/utils';

interface SplitViewProps {
  left: React.ReactNode;
  right: React.ReactNode;
  defaultLeftSize?: number;
  minLeftSize?: number;
  minRightSize?: number;
  leftCollapsible?: boolean;
  autoSaveId?: string;
  className?: string;
  onLeftCollapse?: () => void;
  onLeftExpand?: () => void;
}

export function SplitView({
  left,
  right,
  defaultLeftSize = 35,
  minLeftSize = 20,
  minRightSize = 30,
  leftCollapsible = false,
  autoSaveId,
  className,
  onLeftCollapse,
  onLeftExpand,
}: SplitViewProps) {
  const leftPanelRef = useRef<PanelImperativeHandle>(null);
  const wasCollapsedRef = useRef(false);

  // autoSaveId가 있으면 localStorage에 레이아웃 저장
  const layoutProps = autoSaveId
    ? useDefaultLayout({
        id: autoSaveId,
        storage: localStorage,
      })
    : { defaultLayout: undefined, onLayoutChanged: undefined };

  // 패널 크기 변경 시 collapse/expand 감지
  const handleLeftResize = (panelSize: { asPercentage: number; inPixels: number }) => {
    const isCollapsed = panelSize.asPercentage === 0;

    if (isCollapsed && !wasCollapsedRef.current) {
      wasCollapsedRef.current = true;
      onLeftCollapse?.();
    } else if (!isCollapsed && wasCollapsedRef.current) {
      wasCollapsedRef.current = false;
      onLeftExpand?.();
    }
  };

  return (
    <Group
      orientation="horizontal"
      defaultLayout={layoutProps.defaultLayout}
      onLayoutChanged={layoutProps.onLayoutChanged}
      className={cn('h-full', className)}
    >
      <Panel
        id="left"
        defaultSize={`${defaultLeftSize}%`}
        minSize={`${minLeftSize}%`}
        collapsible={leftCollapsible}
        panelRef={leftPanelRef}
        onResize={handleLeftResize}
        className="overflow-hidden"
      >
        {left}
      </Panel>
      <Separator className="w-1 bg-gray-200 hover:bg-blue-500 transition-colors cursor-col-resize data-[state=dragging]:bg-blue-600" />
      <Panel
        id="right"
        minSize={`${minRightSize}%`}
        className="overflow-hidden"
      >
        {right}
      </Panel>
    </Group>
  );
}
