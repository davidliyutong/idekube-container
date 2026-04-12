<template>
    <div class="controls">
        <button class="control-button lang-toggle" @click="toggleLanguage" aria-label="Toggle language">
            {{ buttonLabel }}
        </button>
        <button class="control-button" @click="toggleTheme" aria-label="Toggle theme">
            {{ toggleIcon }}
        </button>
    </div>
</template>

<script setup lang="ts">
import { useTheme } from '../composables/useTheme'
import { useLanguage } from '../composables/useLanguage'

const { toggleIcon, toggleTheme } = useTheme()
const { buttonLabel, toggleLanguage } = useLanguage()
</script>

<style scoped>
.controls {
    position: fixed;
    top: 24px;
    right: 24px;
    display: flex;
    gap: 12px;
    z-index: 100;
}

.control-button {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: var(--bg-card);
    border: 1px solid var(--border);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
    box-shadow: 0 4px 12px var(--shadow);
    transition: all 0.3s ease;
}

.control-button:hover {
    transform: scale(1.05);
    box-shadow: 0 6px 20px var(--shadow-hover);
}

.lang-toggle {
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-primary);
}

@media (max-width: 768px) {
    .controls {
        top: 16px;
        right: 16px;
    }

    .control-button {
        width: 44px;
        height: 44px;
    }
}
</style>
