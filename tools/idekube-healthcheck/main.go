package main

import (
	"fmt"
	"os"

	"github.com/gin-gonic/gin"
)

const listenAddr = ":9999"

func main() {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())

	r.GET("/", healthHandler)

	fmt.Printf("idekube-healthcheck listening on %s\n", listenAddr)
	if err := r.Run(listenAddr); err != nil {
		fmt.Fprintf(os.Stderr, "failed to start server: %v\n", err)
		os.Exit(1)
	}
}
