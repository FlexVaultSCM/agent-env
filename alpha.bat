@echo off
call "%~dp0wslg-compose.bat" up -d
podman exec -it dev-container-alpha zsh
