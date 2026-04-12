import { ref, watch } from 'vue'
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
  const services = ref<DetectedService[]>([])
  const loading = ref(true)

  async function detectServices() {
    loading.value = true
    const detected: DetectedService[] = []
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
          const response = await fetch(`/${config.path}/`, {
            method: 'GET',
            redirect: 'manual',
          })
          if (
            response.status !== 0 &&
            response.status !== 301 &&
            response.status !== 302 &&
            response.status !== 404
          ) {
            available = true
          }
        }

        if (available) {
          const t = landingTranslations[lang.value]?.services[config.path]
          detected.push({
            path: config.path,
            icon: config.icon,
            name: t?.name ?? config.path,
            description: t?.description ?? '',
            action: t?.action,
          })
        }
      } catch {
        // Service not available
      }
    }

    services.value = detected
    loading.value = false
  }

  watch(lang, () => {
    detectServices()
  })

  detectServices()

  return { services, loading }
}
