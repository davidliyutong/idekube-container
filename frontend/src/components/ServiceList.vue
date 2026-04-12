<template>
    <div class="services">
        <div v-if="loading" class="loading">
            {{ landingTranslations[lang].loading }}
        </div>
        <div v-else-if="services.length === 0" class="loading">
            {{ landingTranslations[lang].noServices }}
        </div>
        <ServiceCard v-else v-for="service in services" :key="service.path" :service="service" />
    </div>
</template>

<script setup lang="ts">
import { useServiceDetection } from '../composables/useServiceDetection'
import { useLanguage } from '../composables/useLanguage'
import { landingTranslations } from '../config/translations'
import ServiceCard from './ServiceCard.vue'

const { services, loading } = useServiceDetection()
const { lang } = useLanguage()
</script>

<style scoped>
.services {
    display: grid;
    gap: 12px;
    margin-bottom: 40px;
}

.loading {
    text-align: center;
    color: var(--text-secondary);
    padding: 40px;
}

.loading::after {
    content: "...";
    animation: dots 1.5s steps(4, end) infinite;
}

@keyframes dots {
    0%,
    20% {
        content: ".";
    }
    40% {
        content: "..";
    }
    60%,
    100% {
        content: "...";
    }
}
</style>
