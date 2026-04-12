<template>
    <div>
    <ControlButtons />

    <div class="container">
        <div class="lock-icon">{{'🔒'}}</div>
        <h1 class="title">{{ authTranslations[lang].title }}</h1>
        <p class="description">{{ authTranslations[lang].description }}</p>

        <TokenForm />

        <div class="footer">
            <p>{{ authTranslations[lang].footer }}</p>
        </div>
    </div>
    </div>
</template>

<script setup lang="ts">
import ControlButtons from '../components/ControlButtons.vue'
import TokenForm from '../components/TokenForm.vue'
import { useLanguage } from '../composables/useLanguage'
import { authTranslations } from '../config/translations'

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
    max-width: 500px;
    width: 100%;
    transition: all 0.3s ease;
    text-align: center;
}

.lock-icon {
    font-size: 4rem;
    margin-bottom: 24px;
    display: inline-block;
}

.title {
    font-size: 1.75rem;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 12px;
}

.description {
    color: var(--text-secondary);
    font-size: 1rem;
    margin-bottom: 36px;
    line-height: 1.6;
}

.footer {
    color: var(--text-tertiary);
    font-size: 0.875rem;
    margin-top: 32px;
    padding-top: 24px;
    border-top: 1px solid var(--border);
}

@media (max-width: 768px) {
    .container {
        padding: 40px 32px;
    }
}

@media (max-width: 480px) {
    .container {
        padding: 32px 24px;
    }

    .title {
        font-size: 1.5rem;
    }
}
</style>
