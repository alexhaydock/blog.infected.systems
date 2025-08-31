+++
title = 'Cheatsheet'
date = 1970-01-01T00:00:00Z
draft = false
+++

My cheatsheet of useful (or semi-useful) commands.

Most of these are focused on bootstrapping or setting up new or temporary systems where I don't yet have all my documentation available / synced.

## GNOME - Scale text to 140%
```sh
gsettings set org.gnome.desktop.interface text-scaling-factor 1.4
```

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

## Configure Chrony with NTS time sources
Based on the config from GrapheneOS. Tested on Proxmox and Fedora.
```sh
sudo systemctl stop chrony && echo -e 'server time.cloudflare.com iburst nts\nserver ntppool1.time.nl iburst nts\nserver nts.netnod.se iburst nts\nserver ptbtime1.ptb.de iburst nts\nserver time.dfm.dk iburst nts\nserver time.cifelli.xyz iburst nts\nminsources 3\nauthselectmode require\ndscp 46\ndriftfile /var/lib/chrony/drift\ndumpdir /var/lib/chrony\nntsdumpdir /var/lib/chrony\nleapseclist /usr/share/zoneinfo/leap-seconds.list\nmakestep 1 3\nrtconutc\nrtcsync\ncmdport 0\nnoclientlog' | sudo tee /etc/chrony/chrony.conf && sudo systemctl start chrony
```
