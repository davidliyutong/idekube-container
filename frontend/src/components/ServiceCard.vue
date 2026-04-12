<template>
    <a
        :href="isCopyAction ? 'javascript:void(0)' : `/${service.path}/`"
        class="service-card"
        :id="`service-${service.path}`"
        @click="handleClick"
    >
        <div class="service-icon-wrapper">{{ service.icon }}</div>
        <div class="service-content">
            <div class="service-name">
                <span class="service-status"></span>
                {{ service.name }}
            </div>
            <div class="service-description" :style="descriptionStyle">
                {{ displayDescription }}
            </div>
        </div>
        <div class="service-arrow">{{ isCopyAction ? '\u{1F4CB}' : '\u2192' }}</div>
    </a>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { DetectedService } from '../composables/useServiceDetection'
import { useLanguage } from '../composables/useLanguage'

const props = defineProps<{
    service: DetectedService
}>()

const { lang } = useLanguage()
const copiedRecently = ref(false)
const descriptionStyle = ref<Record<string, string>>({})

const isCopyAction = computed(() => props.service.action === 'copy-ssh')

const displayDescription = computed(() => {
    if (copiedRecently.value) {
        return lang.value === 'zh' ? '\u5DF2\u590D\u5236 ProxyCommand!' : 'ProxyCommand Copied!'
    }
    return props.service.description
})

function handleClick(e: MouseEvent) {
    if (!isCopyAction.value) return

    e.preventDefault()

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const host = window.location.host
    const hostname = window.location.hostname
    const wsUrl = `${protocol}//${host}/${props.service.path}/`

    const command = `Host ${hostname}\n    ProxyCommand websocat --binary ${wsUrl}\n    User idekube`

    navigator.clipboard
        .writeText(command)
        .then(() => {
            copiedRecently.value = true
            descriptionStyle.value = { color: 'var(--primary)' }

            setTimeout(() => {
                copiedRecently.value = false
                descriptionStyle.value = {}
            }, 2000)
        })
        .catch((err) => {
            console.error('Failed to copy text: ', err)
        })
}
</script>

<style scoped>
.service-card {
    display: flex;
    align-items: center;
    padding: 20px 24px;
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 16px;
    text-decoration: none;
    color: inherit;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    cursor: pointer;
    position: relative;
    overflow: hidden;
}

.service-card::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    width: 4px;
    height: 100%;
    background: linear-gradient(135deg, var(--primary), var(--accent));
    transform: scaleY(0);
    transition: transform 0.3s ease;
}

.service-card:hover {
    transform: translateX(4px);
    box-shadow: 0 12px 24px var(--shadow-hover);
    border-color: var(--primary);
}

.service-card:hover::before {
    transform: scaleY(1);
}

.service-icon-wrapper {
    font-size: 2rem;
    margin-right: 20px;
    filter: grayscale(0.3);
    transition: all 0.3s ease;
}

.service-card:hover .service-icon-wrapper {
    filter: grayscale(0);
    transform: scale(1.1);
}

.service-content {
    flex: 1;
}

.service-name {
    font-size: 1.25rem;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 4px;
    display: flex;
    align-items: center;
    gap: 8px;
}

.service-status {
    display: inline-block;
    width: 8px;
    height: 8px;
    background: var(--accent);
    border-radius: 50%;
    animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
    0%,
    100% {
        opacity: 1;
    }
    50% {
        opacity: 0.5;
    }
}

.service-description {
    font-size: 0.875rem;
    color: var(--text-tertiary);
    font-weight: 400;
}

.service-arrow {
    color: var(--text-tertiary);
    font-size: 1.25rem;
    transition: all 0.3s ease;
    opacity: 0;
}

.service-card:hover .service-arrow {
    opacity: 1;
    transform: translateX(4px);
}

@media (max-width: 480px) {
    .service-card {
        padding: 16px 20px;
    }

    .service-icon-wrapper {
        font-size: 1.5rem;
        margin-right: 16px;
    }

    .service-name {
        font-size: 1.125rem;
    }
}
</style>
