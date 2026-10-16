@echo off
rem podman-compose with the WSLg overlay applied, e.g. "wslg-compose build" or "wslg-compose up -d"
podman-compose -f podman-compose.yml -f podman-compose.wslg.yml %*
