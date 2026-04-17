import { ref, computed, onScopeDispose } from 'vue'
import { serviceConfigs } from '../config/services'
import { landingTranslations } from '../config/translations'
import { useLanguage } from './useLanguage'

const PROBE_TIMEOUT_MS = 2000
const REFRESH_INTERVAL_MS = 10_000

export interface DetectedService {
  path: string
  icon: string
  name: string
  description: string
  action?: string
}

interface HealthService {
  port: number
  path: string
  healthy: boolean
}

interface HealthResponse {
  status: string
  branch: string
  entry: string
  services: Record<string, HealthService>
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

  function iconForPath(path: string): string {
    return serviceConfigs.find((c) => c.path === path)?.icon ?? '🔧'
  }

  async function detectViaHealth(): Promise<boolean> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), PROBE_TIMEOUT_MS)
    try {
      const resp = await fetch('/health', { signal: controller.signal })
      clearTimeout(timer)
      if (!resp.ok) return false
      const data: HealthResponse = await resp.json()
      const detected: { path: string; icon: string }[] = []
      for (const [, svc] of Object.entries(data.services)) {
        if (svc.healthy) {
          // Use the service path without leading slash as the key
          const pathKey = svc.path.replace(/^\//, '').replace(/\/$/, '')
          detected.push({ path: pathKey, icon: iconForPath(pathKey) })
        }
      }
      detectedPaths.value = detected
      return true
    } catch {
      clearTimeout(timer)
      return false
    }
  }

  async function probeServiceHttp(path: string): Promise<boolean> {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), PROBE_TIMEOUT_MS)
    try {
      const response = await fetch(`/${path}/`, {
        method: 'GET',
        signal: controller.signal,
      })
      clearTimeout(timer)
      const finalUrl = new URL(response.url)
      if (!response.redirected || finalUrl.pathname.startsWith(`/${path}`)) {
        if (response.ok || response.status === 401 || response.status === 403) {
          return true
        }
      }
      return false
    } catch {
      clearTimeout(timer)
      return false
    }
  }

  async function probeServiceWs(path: string): Promise<boolean> {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const host = window.location.host
    return new Promise<boolean>((resolve) => {
      const socket = new WebSocket(`${protocol}//${host}/${path}/`)
      const timer = setTimeout(() => {
        socket.close()
        resolve(false)
      }, PROBE_TIMEOUT_MS)
      socket.onopen = () => {
        clearTimeout(timer)
        socket.close()
        resolve(true)
      }
      socket.onerror = () => {
        clearTimeout(timer)
        resolve(false)
      }
    })
  }

  async function detectViaProbes(): Promise<void> {
    const results = await Promise.allSettled(
      serviceConfigs.map(async (config) => {
        const available =
          config.detectionMethod === 'websocket'
            ? await probeServiceWs(config.path)
            : await probeServiceHttp(config.path)
        return available ? { path: config.path, icon: config.icon } : null
      }),
    )
    detectedPaths.value = results
      .filter(
        (r): r is PromiseFulfilledResult<{ path: string; icon: string }> =>
          r.status === 'fulfilled' && r.value !== null,
      )
      .map((r) => r.value)
  }

  async function detectServices() {
    loading.value = true
    // Try /health endpoint first; fall back to parallel individual probes
    const ok = await detectViaHealth()
    if (!ok) {
      await detectViaProbes()
    }
    loading.value = false
  }

  detectServices()

  const intervalId = setInterval(detectServices, REFRESH_INTERVAL_MS)
  onScopeDispose(() => clearInterval(intervalId))

  return { services, loading }
}
