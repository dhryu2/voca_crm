import { useEffect, useState, useCallback } from 'react';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SlidePanelProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  description?: string;
  children: React.ReactNode;
  width?: 'sm' | 'md' | 'lg' | 'xl';
}

export function SlidePanel({
  isOpen,
  onClose,
  title,
  description,
  children,
  width = 'md',
}: SlidePanelProps) {
  const [shouldRender, setShouldRender] = useState(isOpen);
  const [isAnimating, setIsAnimating] = useState(false);

  const widths = {
    sm: 'max-w-sm',
    md: 'max-w-md',
    lg: 'max-w-lg',
    xl: 'max-w-xl',
  };

  // 진입/퇴장 애니메이션 관리
  useEffect(() => {
    if (isOpen) {
      setShouldRender(true);
      // 다음 프레임에 애니메이션 시작 (DOM 렌더링 후)
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setIsAnimating(true);
        });
      });
    } else if (shouldRender) {
      setIsAnimating(false);
      // 애니메이션 완료 후 DOM 제거 (300ms 트랜지션)
      const timer = setTimeout(() => {
        setShouldRender(false);
      }, 300);
      return () => clearTimeout(timer);
    }
  }, [isOpen, shouldRender]);

  // ESC 키로 닫기
  const handleEscape = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    },
    [onClose]
  );

  useEffect(() => {
    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, handleEscape]);

  if (!shouldRender) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      {/* Backdrop with fade transition */}
      <div
        className={cn(
          'absolute inset-0 bg-black transition-opacity duration-300',
          isAnimating ? 'opacity-50' : 'opacity-0'
        )}
        onClick={onClose}
      />

      {/* Panel with slide transition */}
      <div
        className={cn(
          'relative w-full bg-white shadow-xl flex flex-col h-full transition-transform duration-300 ease-out',
          widths[width],
          isAnimating ? 'translate-x-0' : 'translate-x-full'
        )}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <div>
            {title && (
              <h2 className="text-lg font-semibold text-gray-900">{title}</h2>
            )}
            {description && (
              <p className="text-sm text-gray-500 mt-0.5">{description}</p>
            )}
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">{children}</div>
      </div>
    </div>
  );
}
