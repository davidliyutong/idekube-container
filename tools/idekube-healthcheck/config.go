package main

import (
	"encoding/json"
	"fmt"
	"os"
)

const configPath = "/etc/idekube/health.json"

type ServiceConfig struct {
	Port      int    `json:"port"`
	Path      string `json:"path"`
	ProbePath string `json:"probePath,omitempty"`
}

type HealthConfig struct {
	Branch   string                   `json:"branch"`
	Entry    string                   `json:"entry"`
	Main     string                   `json:"main"`
	Services map[string]ServiceConfig `json:"services"`
}

func loadConfig() (*HealthConfig, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}
	var cfg HealthConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	return &cfg, nil
}
