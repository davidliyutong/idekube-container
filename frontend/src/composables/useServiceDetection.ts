import { ref, computed } from 'vue'
import { serviceConfigs } from '../config/services'
import { landingTranslations } from '../config/translations'
import { useLanguage } from './useLanguage'

export interface DetectedService {
  path: string
  icon: string
  name: string
  description: string
  action?: string
}

export function useServiceDetection() {
  const { lang } = useLanguage()
  // Raw detection results (path + icon only, language-independent)
  const detectedPaths = ref<{ path: string; icon: string }[]>([])
  const loading = ref(true)

  // Derive translated service list reactively — no re-probe on lang change
  const services = computed<DetectedService[]>(() =>
    detectedPaths.value.map((d) => {
      const t = landingTranslations[lang.value]?.services[d.path]
      return {
        path: d.path,
        icon: d.icon,
        name: t?.name ?? d.path,
        description: t?.description ?? '',
        action: t?.action,
      }
    }),
  )

  async function detectServices() {
    loading.value = true
    const detected: { path: string; icon: string }[] = []
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const host = window.location.host

    for (const config of serviceConfigs) {
      try {
        let available = false

        if (config.detectionMethod === 'websocket') {
          available = await new Promise<boolean>((resolve) => {
            const socket = new WebSocket(`${protocol}//${host}/${config.path}/`)
            socket.onopen = () => {
              socket.close()
              resolve(true)
            }
            socket.onerror = () => {
              resolve(false)
            }
          })
        } else {
          // Follow redirects normally; if the final URL was redirected
          // away from the probed path (404 → fallback to /), the service
          // is absent. Legitimate 301s (e.g. /coder → /coder/) stay
          // under the same path prefix so they pass the check.
          const response = await fetch(`/${config.path}/`, { method: 'GET' })
          const finalUrl = new URL(response.url)
          if (
            !response.redirected ||
            finalUrl.pathname.startsWith(`/${config.path}`)
          ) {
            if (response.ok || response.status === 401 || response.status === 403) {
              available = true
            }
          }
        }

        if (available) {
          detected.push({ path: config.path, icon: config.icon })
        }
      } catch {
        // Service not available
      }
    }

    detectedPaths.value = detected
    loading.value = false
  }

  detectServices()

  return { services, loading }
}
