import { X } from 'lucide-react';

interface ShortcutGroup {
  title: string;
  shortcuts: { keys: string[]; description: string }[];
}

interface KeyboardShortcutsHelpProps {
  isOpen: boolean;
  onClose: () => void;
}

const shortcutGroups: ShortcutGroup[] = [
  {
    title: '전역',
    shortcuts: [
      { keys: ['Ctrl', 'K'], description: '명령어 팔레트 열기' },
      { keys: ['Ctrl', '/'], description: '단축키 도움말' },
      { keys: ['Esc'], description: '모달/패널 닫기' },
    ],
  },
  {
    title: '목록',
    shortcuts: [
      { keys: ['↑', '↓'], description: '항목 탐색' },
      { keys: ['Enter'], description: '선택 항목 열기' },
      { keys: ['Ctrl', 'N'], description: '새 항목 생성' },
    ],
  },
  {
    title: '편집',
    shortcuts: [
      { keys: ['Ctrl', 'S'], description: '저장' },
      { keys: ['Ctrl', 'Enter'], description: '텍스트 영역 저장' },
      { keys: ['Esc'], description: '편집 취소' },
    ],
  },
];

export function KeyboardShortcutsHelp({ isOpen, onClose }: KeyboardShortcutsHelpProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* Panel */}
      <div className="relative w-full max-w-md bg-white rounded-lg shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">키보드 단축키</h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 space-y-6 max-h-[60vh] overflow-y-auto">
          {shortcutGroups.map((group) => (
            <div key={group.title}>
              <h3 className="text-sm font-medium text-gray-500 mb-3">{group.title}</h3>
              <div className="space-y-2">
                {group.shortcuts.map((shortcut, index) => (
                  <div key={index} className="flex items-center justify-between">
                    <span className="text-sm text-gray-700">{shortcut.description}</span>
                    <div className="flex items-center gap-1">
                      {shortcut.keys.map((key, i) => (
                        <span key={i}>
                          <kbd className="px-2 py-1 text-xs bg-gray-100 rounded border border-gray-200 font-mono">
                            {key}
                          </kbd>
                          {i < shortcut.keys.length - 1 && <span className="mx-1 text-gray-400">+</span>}
                        </span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
