<template>
    <form class="token-form" @submit.prevent="handleSubmit">
        <input
            type="password"
            class="token-input"
            ref="inputRef"
            v-model="tokenValue"
            :placeholder="authTranslations[lang].placeholder"
            autocomplete="off"
            autofocus
            @input="hideError"
        />
        <p class="error-message" :class="{ visible: showError }">
            {{ errorMessage }}
        </p>
        <button type="submit" class="submit-button">
            {{ authTranslations[lang].submit }}
        </button>
    </form>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useLanguage } from '../composables/useLanguage'
import { authTranslations } from '../config/translations'

const { lang } = useLanguage()
const tokenValue = ref('')
const showError = ref(false)
const wasInvalidAttempt = ref(false)
const inputRef = ref<HTMLInputElement | null>(null)

const errorMessage = computed(() => {
    if (wasInvalidAttempt.value) {
        return authTranslations[lang.value].invalidToken
    }
    return authTranslations[lang.value].error
})

onMounted(() => {
    // When the token is wrong, nginx does NOT rewrite (the arg_ok map
    // returns 0), so the query param stays in the URL and auth_request
    // returns 401.  Detect this to show an "invalid token" message.
    const params = new URLSearchParams(window.location.search)
    if (params.has('idekube-container-access-token')) {
        wasInvalidAttempt.value = true
        showError.value = true
        // Clean the URL so the error doesn't persist on manual reload
        const url = new URL(window.location.href)
        url.search = ''
        window.history.replaceState({}, document.title, url.toString())
    }
    inputRef.value?.focus()
})

function hideError() {
    showError.value = false
    wasInvalidAttempt.value = false
}

function handleSubmit() {
    const token = tokenValue.value.trim()
    if (!token) {
        showError.value = true
        return
    }
    showError.value = false
    const url = new URL(window.location.href)
    url.searchParams.set('idekube-container-access-token', token)
    window.location.href = url.toString()
}
</script>

<style scoped>
.token-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.token-input {
    width: 100%;
    padding: 16px 20px;
    border: 2px solid var(--border);
    border-radius: 12px;
    font-size: 1rem;
    font-family: inherit;
    background: var(--bg-secondary);
    color: var(--text-primary);
    outline: none;
    transition: all 0.3s ease;
    text-align: center;
    letter-spacing: 0.05em;
}

.token-input::placeholder {
    color: var(--text-tertiary);
    letter-spacing: normal;
}

.token-input:focus {
    border-color: var(--primary);
    box-shadow: 0 0 0 4px rgba(43, 122, 139, 0.15);
}

.submit-button {
    width: 100%;
    padding: 16px 24px;
    background: linear-gradient(135deg, var(--primary) 0%, var(--accent) 100%);
    color: #ffffff;
    border: none;
    border-radius: 12px;
    font-size: 1.05rem;
    font-weight: 600;
    font-family: inherit;
    cursor: pointer;
    transition: all 0.3s ease;
}

.submit-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(43, 122, 139, 0.3);
}

.submit-button:active {
    transform: translateY(0);
}

.error-message {
    color: #ef4444;
    font-size: 0.875rem;
    margin-top: 4px;
    display: none;
}

.error-message.visible {
    display: block;
}
</style>
