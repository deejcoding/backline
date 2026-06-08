import { create } from 'zustand'

interface UIState {
  isMobileMenuOpen: boolean
  isModalOpen: boolean
  modalContent: React.ReactNode | null
  toastMessage: string | null
  toastType: 'success' | 'error' | 'info'

  // Actions
  openMobileMenu: () => void
  closeMobileMenu: () => void
  toggleMobileMenu: () => void
  openModal: (content: React.ReactNode) => void
  closeModal: () => void
  showToast: (message: string, type?: 'success' | 'error' | 'info') => void
  hideToast: () => void
}

export const useUIStore = create<UIState>((set) => ({
  isMobileMenuOpen: false,
  isModalOpen: false,
  modalContent: null,
  toastMessage: null,
  toastType: 'info',

  openMobileMenu: () => set({ isMobileMenuOpen: true }),
  closeMobileMenu: () => set({ isMobileMenuOpen: false }),
  toggleMobileMenu: () => set((state) => ({ isMobileMenuOpen: !state.isMobileMenuOpen })),

  openModal: (content) => set({ isModalOpen: true, modalContent: content }),
  closeModal: () => set({ isModalOpen: false, modalContent: null }),

  showToast: (message, type = 'info') => {
    set({ toastMessage: message, toastType: type })
    setTimeout(() => set({ toastMessage: null }), 4000)
  },
  hideToast: () => set({ toastMessage: null }),
}))
