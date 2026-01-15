import { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Users, Calendar, FileText, Settings, BarChart3, MapPin } from 'lucide-react';
import { cn } from '@/lib/utils';

interface CommandItem {
  id: string;
  label: string;
  icon: React.ReactNode;
  action: () => void;
  keywords?: string[];
}

interface CommandPaletteProps {
  isOpen: boolean;
  onClose: () => void;
}

export function CommandPalette({ isOpen, onClose }: CommandPaletteProps) {
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const navigate = useNavigate();

  const commands: CommandItem[] = useMemo(() => [
    { id: 'customers', label: '고객 관리', icon: <Users className="w-4 h-4" />, action: () => navigate('/customers'), keywords: ['회원', 'member'] },
    { id: 'reservations', label: '예약 관리', icon: <Calendar className="w-4 h-4" />, action: () => navigate('/reservations'), keywords: ['예약', 'booking'] },
    { id: 'visits', label: '방문 기록', icon: <MapPin className="w-4 h-4" />, action: () => navigate('/visits'), keywords: ['방문', 'checkin'] },
    { id: 'memos', label: '메모', icon: <FileText className="w-4 h-4" />, action: () => navigate('/memos'), keywords: ['노트', 'note'] },
    { id: 'dashboard', label: '대시보드', icon: <BarChart3 className="w-4 h-4" />, action: () => navigate('/dashboard'), keywords: ['통계', 'stats'] },
    { id: 'settings', label: '설정', icon: <Settings className="w-4 h-4" />, action: () => navigate('/settings'), keywords: ['환경설정', 'config'] },
  ], [navigate]);

  const filteredCommands = useMemo(() => {
    if (!query) return commands;
    const q = query.toLowerCase();
    return commands.filter(cmd =>
      cmd.label.toLowerCase().includes(q) ||
      cmd.keywords?.some(k => k.toLowerCase().includes(q))
    );
  }, [commands, query]);

  useEffect(() => {
    if (isOpen) {
      setQuery('');
      setSelectedIndex(0);
      setTimeout(() => inputRef.current?.focus(), 10);
    }
  }, [isOpen]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex(i => Math.min(i + 1, filteredCommands.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex(i => Math.max(i - 1, 0));
        break;
      case 'Enter':
        e.preventDefault();
        if (filteredCommands[selectedIndex]) {
          filteredCommands[selectedIndex].action();
          onClose();
        }
        break;
      case 'Escape':
        e.preventDefault();
        onClose();
        break;
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center pt-[20vh]">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* Panel */}
      <div className="relative w-full max-w-lg bg-white rounded-lg shadow-xl overflow-hidden">
        {/* Search Input */}
        <div className="flex items-center px-4 border-b border-gray-200">
          <Search className="w-5 h-5 text-gray-400" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="명령어 또는 페이지 검색..."
            className="w-full px-3 py-4 outline-none text-gray-900 placeholder-gray-400"
          />
          <kbd className="px-2 py-1 text-xs bg-gray-100 rounded text-gray-500">ESC</kbd>
        </div>

        {/* Results */}
        <div className="max-h-64 overflow-y-auto py-2">
          {filteredCommands.length === 0 ? (
            <p className="px-4 py-3 text-sm text-gray-500">검색 결과가 없습니다</p>
          ) : (
            filteredCommands.map((cmd, index) => (
              <button
                key={cmd.id}
                onClick={() => {
                  cmd.action();
                  onClose();
                }}
                className={cn(
                  'w-full px-4 py-2 flex items-center gap-3 text-left transition-colors',
                  index === selectedIndex ? 'bg-blue-50 text-blue-700' : 'text-gray-700 hover:bg-gray-50'
                )}
              >
                {cmd.icon}
                <span>{cmd.label}</span>
              </button>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
