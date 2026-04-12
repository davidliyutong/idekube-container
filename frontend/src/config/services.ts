export interface ServiceConfig {
  path: string
  icon: string
  detectionMethod: 'http' | 'websocket'
}

export const serviceConfigs: ServiceConfig[] = [
  { path: 'vnc', icon: '\u{1F5A5}\uFE0F', detectionMethod: 'http' },
  { path: 'coder', icon: '\u{1F4BB}', detectionMethod: 'http' },
  { path: 'jupyter', icon: '\u{1F4CA}', detectionMethod: 'http' },
  { path: 'ssh', icon: '\u2328\uFE0F', detectionMethod: 'websocket' },
  { path: 'agent', icon: '\u{1F916}', detectionMethod: 'http' },
  { path: 'terminal', icon: '\u{1F5A5}\uFE0F', detectionMethod: 'http' },
]
