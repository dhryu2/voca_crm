import { create } from 'zustand';

interface UIState {
  isCommandPaletteOpen: boolean;
  isShortcutsHelpOpen: boolean;
  openCommandPalette: () => void;
  closeCommandPalette: () => void;
  toggleCommandPalette: () => void;
  openShortcutsHelp: () => void;
  closeShortcutsHelp: () => void;
  toggleShortcutsHelp: () => void;
}

export const useUIStore = create<UIState>((set) => ({
  isCommandPaletteOpen: false,
  isShortcutsHelpOpen: false,
  openCommandPalette: () => set({ isCommandPaletteOpen: true }),
  closeCommandPalette: () => set({ isCommandPaletteOpen: false }),
  toggleCommandPalette: () => set((state) => ({ isCommandPaletteOpen: !state.isCommandPaletteOpen })),
  openShortcutsHelp: () => set({ isShortcutsHelpOpen: true }),
  closeShortcutsHelp: () => set({ isShortcutsHelpOpen: false }),
  toggleShortcutsHelp: () => set((state) => ({ isShortcutsHelpOpen: !state.isShortcutsHelpOpen })),
}));
