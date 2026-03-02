@echo off
podman-compose up -d
podman exec -it dev-container-alpha zsh