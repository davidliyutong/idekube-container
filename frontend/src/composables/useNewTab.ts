import { ref } from 'vue'

const openInNewTab = ref(false)

function initNewTab() {
  const params = new URLSearchParams(window.location.search)
  const value = params.get('newtab')
  openInNewTab.value = value === 'true' || value === '1' || value === 'yes'
}

initNewTab()

export function useNewTab() {
  return { openInNewTab }
}
