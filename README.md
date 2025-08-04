# 🌐 Mini Algernon - Lightweight Web Server

A feature-packed bash-based web server for Linux/Termux  
Lightweight, dependency-aware, and tunneling-ready server for PHP/static sites with automatic setup.

!Demo 
!Bash 
!Termux

## Features ✨

- Dual Server Modes  
  ✅ Built-in PHP server (php -S)  
  ✅ Custom static file server (netcat-based)
- Auto-Tunnel Support  
  - Ngrok (with auth setup)  
  - Serveo (SSH-based)  
  - Localtunnel (npm-based)
- Zero-Config Setup  
  Auto-creates professional index pages:
  - Elegant PHP/HTML homepage
  - Detailed server-info dashboard (system metrics, PHP config, security audit)
- Cross-Platform  
  Works on Linux and Termux (Android)
- Smart Dependency Handling  
  Auto-installs PHP/netcat when missing
- Interactive Wizard  
  Guided setup for beginners
- Verbose Logging  
  Debug mode with request monitoring

## Installation ⚡

curl -O https://raw.githubusercontent.com/yourusername/mini-algernon/main/mini-algernon.sh
chmod +x mini-algernon.sh

## Usage 🚀

### Basic
./mini-algernon.sh --port 8080 --dir ~/my-site

### With Tunneling
# Ngrok tunnel
./mini-algernon.sh -t ngrok -v

# Serveo tunnel (SSH-based)
./mini-algernon.sh -t serveo

### Options
-p, --port      Port (default: 3001)
-d, --dir       Site directory (default: current)
-t, --tunnel    ngrok|serveo|localtunnel
-v, --verbose   Show request logs
--no-php        Disable PHP mode

## Default Pages 🖼️

### Homepage
![](https://via.placeholder.com/800x400/3498db/ffffff?text=Modern+PHP+%2F+HTML+Homepage)

### Server Dashboard
![](https://via.placeholder.com/800x400/2c3e50/ffffff?text=System+Metrics+%26+Security+Audit)

## Why "Mini Algernon"? 🤔
Named after the Algernon web server, this implementation delivers similar tunneling features in a lightweight bash package (<1KB).

## Termux Support 📱
Perfect for Android development! Handles:
- Automatic PHP installation
- Port forwarding
- Internet exposure via tunnels

## Contribution 🤝
PRs welcome! Features to add:
- [ ] HTTPS support
- [ ] Basic auth
- [ ] Rate limiting

---
Light enough for Raspberry Pi, powerful enough for prototyping 💡
```


1. Badges - Visual markers for compatibility
2. Features - Emoji-enhanced list of core capabilities
3. Tunneling Focus - Clear documentation for ngrok/serveo
4. Visual Placeholders - Areas for future screenshots
5. Termux Specific - Android compatibility callout
6. Philosophy - Background on the project name
7. Roadmap - Clear contribution opportunities

The description emphasizes:
- Zero-configuration magic
- Cross-platform support
- Professional default UIs
- Enterprise-like features (server dashboard)
- Mobile development use case
