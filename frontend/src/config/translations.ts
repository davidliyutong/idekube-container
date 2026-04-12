export interface ServiceTranslation {
  name: string
  description: string
  action?: string
}

export interface LandingTranslations {
  subtitle: string
  loading: string
  noServices: string
  footer: string
  services: Record<string, ServiceTranslation>
}

export interface AuthTranslations {
  title: string
  description: string
  placeholder: string
  submit: string
  error: string
  invalidToken: string
  footer: string
}

export const landingTranslations: Record<string, LandingTranslations> = {
  en: {
    subtitle: 'Select a service to get started',
    loading: 'Detecting available services',
    noServices: 'No services available',
    footer: 'IDEKube Container Environment',
    services: {
      vnc: {
        name: 'Desktop',
        description: 'Remote desktop via noVNC',
      },
      coder: {
        name: 'Code Server',
        description: 'VS Code in the browser',
      },
      jupyter: {
        name: 'Jupyter Lab',
        description: 'Interactive notebook environment',
      },
      ssh: {
        name: 'SSH Terminal',
        description: 'Click to copy SSH ProxyCommand configuration',
        action: 'copy-ssh',
      },
      agent: {
        name: 'Agent Gateway',
        description: 'openclaw-backed agent API and web UI',
      },
      terminal: {
        name: 'Web Terminal',
        description: 'Browser-based terminal access',
      },
    },
  },
  zh: {
    subtitle: '\u9009\u62E9\u4E00\u4E2A\u670D\u52A1\u5F00\u59CB\u4F7F\u7528',
    loading: '\u6B63\u5728\u68C0\u6D4B\u53EF\u7528\u670D\u52A1',
    noServices: '\u6682\u65E0\u53EF\u7528\u670D\u52A1',
    footer: 'IDEKube \u5BB9\u5668\u73AF\u5883',
    services: {
      vnc: {
        name: '\u684C\u9762\u73AF\u5883',
        description: '\u901A\u8FC7 noVNC \u8BBF\u95EE\u8FDC\u7A0B\u684C\u9762',
      },
      coder: {
        name: '\u4EE3\u7801\u7F16\u8F91\u5668',
        description: '\u6D4F\u89C8\u5668\u4E2D\u7684 VS Code \u7F16\u8F91\u5668',
      },
      jupyter: {
        name: 'Jupyter Lab',
        description: '\u4EA4\u4E92\u5F0F\u7B14\u8BB0\u672C\u73AF\u5883',
      },
      ssh: {
        name: 'SSH \u7EC8\u7AEF',
        description: '\u70B9\u51FB\u590D\u5236 SSH ProxyCommand \u914D\u7F6E',
        action: 'copy-ssh',
      },
      agent: {
        name: 'Agent \u7F51\u5173',
        description: 'openclaw \u9A71\u52A8\u7684 Agent API \u4E0E Web UI',
      },
      terminal: {
        name: 'Web \u7EC8\u7AEF',
        description: '\u6D4F\u89C8\u5668\u4E2D\u7684\u7EC8\u7AEF\u8BBF\u95EE',
      },
    },
  },
}

export const authTranslations: Record<string, AuthTranslations> = {
  en: {
    title: 'Access Token Required',
    description:
      'This container environment requires an access token. Please enter your token to continue.',
    placeholder: 'Enter access token',
    submit: 'Authenticate',
    error: 'Please enter an access token',
    invalidToken: 'Invalid access token, please try again',
    footer: 'IDEKube Container Environment',
  },
  zh: {
    title: '\u9700\u8981\u8BBF\u95EE\u4EE4\u724C',
    description:
      '\u6B64\u5BB9\u5668\u73AF\u5883\u9700\u8981\u8BBF\u95EE\u4EE4\u724C\u624D\u80FD\u4F7F\u7528\u3002\u8BF7\u8F93\u5165\u60A8\u7684\u8BBF\u95EE\u4EE4\u724C\u4EE5\u7EE7\u7EED\u3002',
    placeholder: '\u8BF7\u8F93\u5165\u8BBF\u95EE\u4EE4\u724C',
    submit: '\u9A8C\u8BC1',
    error: '\u8BF7\u8F93\u5165\u8BBF\u95EE\u4EE4\u724C',
    invalidToken: '\u8BBF\u95EE\u4EE4\u724C\u65E0\u6548\uFF0C\u8BF7\u91CD\u8BD5',
    footer: 'IDEKube \u5BB9\u5668\u73AF\u5883',
  },
}
