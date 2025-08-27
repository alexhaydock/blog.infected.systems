+++
title = 'Cheatsheet'
date = 1970-01-01T00:00:00Z
draft = false
+++

My cheatsheet of useful (or semi-useful) commands.

Most of these are focused on bootstrapping or setting up new or temporary systems where I don't yet have all my documentation available / synced.

## Ubuntu - Enable automatic upgrades (no auto reboot)
```sh
sudo apt install -y unattended-upgrades && echo -e 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades && echo -e 'Unattended-Upgrade::Origins-Pattern {\n        "origin=*";\n};\n\nUnattended-Upgrade::Package-Blacklist {\n};' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades && sudo systemctl enable --now apt-daily.timer && sudo systemctl enable --now apt-daily-upgrade.timer && sudo systemctl enable --now unattended-upgrades.service
```

## Ubuntu - Enable automatic upgrades (with auto reboot)
```sh
sudo apt install -y unattended-upgrades && echo -e 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades && echo -e 'Unattended-Upgrade::Origins-Pattern {\n        "origin=*";\n};\n\nUnattended-Upgrade::Package-Blacklist {\n};\n\nUnattended-Upgrade::Automatic-Reboot "true";\nUnattended-Upgrade::Automatic-Reboot-Time "03:33";' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades && sudo systemctl enable --now apt-daily.timer && sudo systemctl enable --now apt-daily-upgrade.timer && sudo systemctl enable --now unattended-upgrades.service
```

## Fedora Atomic - Enable automatic upgrades (no auto reboot)
```sh
sudo systemctl enable --now rpm-ostreed-automatic.timer
```

## Fedora DNF - Enable automatic upgrades (no auto reboot)
```sh
sudo dnf install -y dnf5-plugin-automatic && echo -e '[commands]\napply_updates = yes\nreboot = never' | sudo tee /etc/dnf/automatic.conf && sudo systemctl enable --now dnf5-automatic.timer
```

## Fedora DNF - Enable automatic upgrades (with auto reboot)
```sh
sudo dnf install -y dnf5-plugin-automatic && echo -e '[commands]\napply_updates = yes\nreboot = when-needed' | sudo tee /etc/dnf/automatic.conf && sudo systemctl enable --now dnf5-automatic.timer
```
