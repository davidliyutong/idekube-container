package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type ServiceStatus struct {
	Port    int    `json:"port"`
	Path    string `json:"path"`
	Healthy bool   `json:"healthy"`
}

type HealthResponse struct {
	Status   string                   `json:"status"`
	Branch   string                   `json:"branch"`
	Entry    string                   `json:"entry"`
	Services map[string]ServiceStatus `json:"services"`
}

func healthHandler(c *gin.Context) {
	cfg, err := loadConfig()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	resp := HealthResponse{
		Branch:   cfg.Branch,
		Entry:    cfg.Entry,
		Services: make(map[string]ServiceStatus),
	}

	allHealthy := true
	mainHealthy := true

	prober := DefaultProber()
	for name, svc := range cfg.Services {
		healthy := prober.Probe(svc)
		resp.Services[name] = ServiceStatus{
			Port:    svc.Port,
			Path:    svc.Path,
			Healthy: healthy,
		}
		if !healthy {
			allHealthy = false
			if name == cfg.Main {
				mainHealthy = false
			}
		}
	}

	if allHealthy {
		resp.Status = "healthy"
	} else {
		resp.Status = "degraded"
	}

	if !mainHealthy {
		c.JSON(http.StatusBadGateway, resp)
		return
	}
	c.JSON(http.StatusOK, resp)
}
