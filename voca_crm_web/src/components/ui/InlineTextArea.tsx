import { useState, useEffect, useRef } from 'react';
import type { KeyboardEvent } from 'react';
import { Pencil, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface InlineTextAreaProps {
  value: string;
  onSave: (value: string) => Promise<void> | void;
  placeholder?: string;
  className?: string;
  textAreaClassName?: string;
  disabled?: boolean;
  showEditIcon?: boolean;
  rows?: number;
  maxLength?: number;
}

export function InlineTextArea({
  value,
  onSave,
  placeholder = '클릭하여 편집',
  className,
  textAreaClassName,
  disabled = false,
  showEditIcon = true,
  rows = 3,
  maxLength,
}: InlineTextAreaProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState(value);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const textAreaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!isEditing) {
      setEditValue(value);
    }
  }, [value, isEditing]);

  useEffect(() => {
    if (isEditing && textAreaRef.current) {
      textAreaRef.current.focus();
      // 커서를 끝으로 이동
      const len = textAreaRef.current.value.length;
      textAreaRef.current.setSelectionRange(len, len);
    }
  }, [isEditing]);

  const handleSave = async () => {
    if (editValue === value) {
      setIsEditing(false);
      setError(null);
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      await onSave(editValue);
      setIsEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : '저장에 실패했습니다');
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    setEditValue(value);
    setIsEditing(false);
    setError(null);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    // Ctrl+Enter로 저장 (일반 Enter는 줄바꿈)
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      handleSave();
    }
    if (e.key === 'Escape') {
      e.preventDefault();
      handleCancel();
    }
  };

  if (isEditing) {
    return (
      <div className={cn('relative', className)}>
        <textarea
          ref={textAreaRef}
          value={editValue}
          onChange={(e) => setEditValue(e.target.value)}
          onBlur={handleSave}
          onKeyDown={handleKeyDown}
          disabled={isSaving}
          rows={rows}
          maxLength={maxLength}
          className={cn(
            'w-full border-2 border-blue-500 rounded bg-transparent outline-none px-2 py-1 resize-none',
            isSaving && 'opacity-50',
            error && 'border-red-500',
            textAreaClassName
          )}
        />
        {isSaving && (
          <Loader2 className="absolute right-2 top-2 w-4 h-4 animate-spin text-blue-500" />
        )}
        <div className="flex justify-between items-center mt-1">
          <p className="text-xs text-gray-400">Ctrl+Enter로 저장, ESC로 취소</p>
          {maxLength && (
            <p className="text-xs text-gray-400">{editValue.length}/{maxLength}</p>
          )}
        </div>
        {error && (
          <p className="text-xs text-red-500 mt-1">{error}</p>
        )}
      </div>
    );
  }

  return (
    <div
      onClick={() => !disabled && setIsEditing(true)}
      className={cn(
        'group relative px-1 -mx-1 rounded transition-colors whitespace-pre-wrap',
        !disabled && 'cursor-pointer hover:bg-gray-100',
        disabled && 'cursor-not-allowed opacity-60',
        className
      )}
    >
      {value || <span className="text-gray-400">{placeholder}</span>}
      {showEditIcon && !disabled && (
        <Pencil className="absolute top-0 right-0 w-3 h-3 text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity" />
      )}
    </div>
  );
}
