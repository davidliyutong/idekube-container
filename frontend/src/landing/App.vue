<template>
    <div>
    <ControlButtons />

    <div class="container">
        <div class="logo-section">
            <h1 class="logo-text">IDEKube</h1>
            <p class="subtitle">{{ landingTranslations[lang].subtitle }}</p>
        </div>

        <ServiceList />

        <div class="footer">
            <p>{{ landingTranslations[lang].footer }}</p>
        </div>
    </div>
    </div>
</template>

<script setup lang="ts">
import ControlButtons from '../components/ControlButtons.vue'
import ServiceList from '../components/ServiceList.vue'
import { useLanguage } from '../composables/useLanguage'
import { landingTranslations } from '../config/translations'

const { lang } = useLanguage()
</script>

<style scoped>
.container {
    background: var(--bg-card);
    backdrop-filter: blur(10px);
    border-radius: 24px;
    border: 1px solid var(--border);
    box-shadow: 0 24px 48px var(--shadow);
    padding: 64px;
    max-width: 800px;
    width: 100%;
    transition: all 0.3s ease;
}

.logo-section {
    text-align: center;
    margin-bottom: 48px;
}

.logo-text {
    font-size: 3rem;
    font-weight: 700;
    letter-spacing: -0.02em;
    color: var(--text-primary);
    margin: 0;
}

.subtitle {
    color: var(--text-secondary);
    font-size: 1.125rem;
    font-weight: 400;
    margin-top: 12px;
}

.footer {
    text-align: center;
    color: var(--text-tertiary);
    font-size: 0.875rem;
    font-weight: 400;
    padding-top: 24px;
    border-top: 1px solid var(--border);
}

@media (max-width: 768px) {
    .container {
        padding: 40px 32px;
    }

    .logo-text {
        font-size: 2.5rem;
    }
}

@media (max-width: 480px) {
    .container {
        padding: 32px 24px;
    }

    .logo-text {
        font-size: 2rem;
    }

    .subtitle {
        font-size: 1rem;
    }
}
</style>
