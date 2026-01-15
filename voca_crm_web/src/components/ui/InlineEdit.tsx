import { useState, useEffect, useRef } from 'react';
import type { KeyboardEvent } from 'react';
import { Pencil, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface InlineEditProps {
  value: string;
  onSave: (value: string) => Promise<void> | void;
  placeholder?: string;
  className?: string;
  inputClassName?: string;
  disabled?: boolean;
  showEditIcon?: boolean;
  validate?: (value: string) => string | null; // 에러 메시지 반환
}

export function InlineEdit({
  value,
  onSave,
  placeholder = '클릭하여 편집',
  className,
  inputClassName,
  disabled = false,
  showEditIcon = true,
  validate,
}: InlineEditProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState(value);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // value prop 변경 시 editValue 동기화
  useEffect(() => {
    if (!isEditing) {
      setEditValue(value);
    }
  }, [value, isEditing]);

  // 편집 모드 진입 시 포커스
  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  const handleSave = async () => {
    // 변경 없으면 저장 안 함
    if (editValue === value) {
      setIsEditing(false);
      setError(null);
      return;
    }

    // 유효성 검사
    if (validate) {
      const validationError = validate(editValue);
      if (validationError) {
        setError(validationError);
        return;
      }
    }

    setIsSaving(true);
    setError(null);

    try {
      await onSave(editValue);
      setIsEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : '저장에 실패했습니다');
      // 에러 시 값 롤백하지 않음 - 사용자가 수정 가능
    } finally {
      setIsSaving(false);
    }
  };

  const handleCancel = () => {
    setEditValue(value);
    setIsEditing(false);
    setError(null);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
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
        <input
          ref={inputRef}
          type="text"
          value={editValue}
          onChange={(e) => setEditValue(e.target.value)}
          onBlur={handleSave}
          onKeyDown={handleKeyDown}
          disabled={isSaving}
          className={cn(
            'w-full border-b-2 border-blue-500 bg-transparent outline-none px-1 py-0.5',
            isSaving && 'opacity-50',
            error && 'border-red-500',
            inputClassName
          )}
        />
        {isSaving && (
          <Loader2 className="absolute right-1 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-blue-500" />
        )}
        {error && (
          <p className="text-xs text-red-500 mt-1">{error}</p>
        )}
      </div>
    );
  }

  return (
    <span
      onClick={() => !disabled && setIsEditing(true)}
      className={cn(
        'group inline-flex items-center gap-1 px-1 -mx-1 rounded transition-colors',
        !disabled && 'cursor-pointer hover:bg-gray-100',
        disabled && 'cursor-not-allowed opacity-60',
        className
      )}
    >
      {value || <span className="text-gray-400">{placeholder}</span>}
      {showEditIcon && !disabled && (
        <Pencil className="w-3 h-3 text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity" />
      )}
    </span>
  );
}
