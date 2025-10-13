+++
title = 'Automated TLS cert renewal with acme.sh and systemd Quadlets'
date = 2025-10-13T20:17:00Z
draft = false
summary = "Using DNS-based ACME challenges to auto-renew certs in my homelab with acme.sh"
tags = ['podman', 'systemd', 'linux']
+++

Recently I've been switching my authoritative DNS provider over to [SERVFAIL](https://servfail.network/) -- a project that was first announced at 38c3 in a talk titled ["we made a globally distributed DNS network for shits and giggles"](https://www.youtube.com/watch?v=ZVkZ21tQXNY).


After making the switch, I had to rework a bunch of my homelab services to allow them to continue renewing their certs via DNS-based ACME challenges. This post details how I'm using [acme.sh](https://github.com/acmesh-official/acme.sh) to automate cert renewals for a lot of my services.

Truthfully, this post is mostly just an excuse to shout about several things I find really useful at the same time:
- acme.sh
- Cert renewal via DNS-based ACME challenges
- SERVFAIL DNS
- systemd Quadlets
- Podman auto-updating containers

## Hiding the homelab
Free TLS CAs like LetsEncrypt and ZeroSSL have made it easier than ever to avoid the dreaded self-signed-cert life that plagues a lot of homelab setups.

But, by default, a lot of projects that implement ACME to renew certs from these providers seem to push users towards the lowest-friction option -- using `http-01` or `tls-alpn-01` to serve a response to a challenge from your subdomain over either HTTP or HTTPS respectively.

This is very easy to implement, and convenient for sites which are already intended to be accessible on the global internet. For a homelab, though, I've always felt this is a lot of attack surface to expose just for the sake of acquiring valid certs.

This is where the `dns-01` challenge comes in. With this, we can use an API key for an authoritative DNS provider to attest that we are in control of the subdomain which we want to issue a cert for.

This works very well for homelab-type services, as we can issue and renew valid certs without exposing any of the actual infrastructure directly to the internet.

## PowerDNS problems
Previously, I was using DigitalOcean as my DNS provider, and I typically use [Caddy](https://caddyserver.com/) where a reverse proxy is needed, or [Certbot](https://certbot.eff.org/) for more standalone services that expect to be fed a certificate on-disk.

SERVFAIL is a great project which implements a PowerDNS-compatible API. But in my case I've been finding that support for PowerDNS APIs is quite variable among projects.

Notably:
* Adding PowerDNS support to Caddy [requires rebuilding Caddy](https://caddyserver.com/docs/modules/dns.providers.powerdns), and [has been broken for some months now](https://github.com/caddy-dns/powerdns/issues/4).
* [PowerDNS support](https://pypi.org/project/certbot-dns-powerdns/) for Certbot is non-native, [unlike DigitalOcean support](https://github.com/certbot/certbot/tree/main/certbot-dns-digitalocean).

## `acme.sh` to the rescue
`acme.sh` is an impressive tool for performing DNS (and HTTP) based ACME cert renewal. Impressively, it's also written entirely in bash without requiring any external dependencies. It's also used by a number of other projects, including the certificate renewal tool within the Proxmox web interface.

I'm hoping to see the PowerDNS support in Caddy fixed eventually. If I get the time, I might investigate how to contribute to this effort, since integration with a DNS provider is also required to enable [Encrypted Client Hello (ECH)](https://caddyserver.com/docs/automatic-https#encrypted-clienthello-ech).

In the meantime, this section covers how I'm issuing and automatically renewing certs using `acme.sh` running inside Podman and configured using a systemd Quadlet.

This isn't intended to be a full guide, so it assumes a Fedora host and that you're operating as root.

### Install Podman
```sh
dnf install -y podman
```

### Set LetsEncrypt as default CA for acme.sh
`acme.sh` defaults to ZeroSSL as the CA for issuing certs rather than LetsEncrypt. There's a (biased) comparison [available on ZeroSSL's site](https://zerossl.com/letsencrypt-alternative/) but I like the idea of injecting some diversity back into the PKI system rather than everything just ending up with LE. Unfortunately I had some timeout issues when trying to issue certs with ZeroSSL so I opted to create a new config, and switch to LetsEncrypt:
```sh
mkdir -p "/etc/acme.sh"
```

```sh
podman run --rm it \
  --net host 
  -v "/etc/acme.sh:/acme.sh:Z" \
  docker.io/neilpang/acme.sh:latest \
    --set-default-ca \
    --server letsencrypt
```

Note that `--net host` isn't strictly needed in these examples, but I've found that it ends up helping the situation when running Podman inside unprivileged LXC containers -- especially IPv6-only ones.

### Register a LetsEncrypt account
```sh
podman run --rm it \
  --net host \
  -v "/etc/acme.sh:/acme.sh:Z" \
  docker.io/neilpang/acme.sh:latest \
    --register-account \
    --server letsencrypt \
    -m certs@infected.systems
```

### Issue a certificate
After registering our account with LetsEncrypt, we can pass our PowerDNS variables for SERVFAIL into the container to issue our first certificate:
```sh
podman run --rm it \
  --net host \
  -v "/etc/acme.sh:/acme.sh:Z" \
  --env PDNS_Url="https://beta.servfail.network/" \
  --env PDNS_ServerId="ns1.fops.at." \
  --env PDNS_Token="yourSERVFAILtokenGOEShere" \
  --env PDNS_Ttl="60" \
  docker.io/neilpang/acme.sh:latest \
    --issue \
    --dns dns_pdns \
    --keylength ec-384 \
    -d example.infected.systems
```

You can vary the options for cert generation [based on the `acme.sh` documentation](https://github.com/acmesh-official/acme.sh).

After running the command above, you should be aware that your PowerDNS API key will be saved in plaintext to `/etc/acme.sh/account.conf`.

### Manually renew a certificate
After running the command above to issue a certificate, `acme.sh` will now keep track of which certs have been issued to our account and will renew all of them (if needed) when this one-shot command is run:
```sh
podman run --rm it \
  --net host \
  -v "/etc/acme.sh:/acme.sh:Z" \
  docker.io/neilpang/acme.sh:latest \
    --cron
```

This command could also be scheduled with `cron` (as the CLI flag would imply is the intent). But `acme.sh` also has a `daemon` mode, which remains resident and renews certs automatically when they get close to expiry. This `daemon` mode is the one I'm going to use in the next section for the long-term renewal strategy.

### Create a systemd Quadlet to handle cert renewal
systemd Quadlets are one of my favourite things about working with Podman. Have you ever wished you could manage a Docker container as if it was a native systemd service? That's basically what Quadlets are. [Though they can do a lot more!](https://www.redhat.com/en/blog/quadlet-podman)

Create a new container unit for `acme.sh` using the best text editor:
```sh
nano /etc/containers/systemd/acme-sh.container
```

Configure the `acme.sh` container to run, with our `/etc/acme.sh` volume bind-mounted, and running in `daemon` mode:
```ini
[Unit]
Description=acme.sh certificate renewal daemon
After=local-fs.target network-online.target

[Container]
Image=docker.io/neilpang/acme.sh:latest
Exec=daemon
Volume=/etc/acme.sh:/acme.sh
Label=io.containers.autoupdate=registry
Network=host

[Install]
WantedBy=multi-user.target default.target
```

Start our newly-created Quadlet:
```sh
systemctl daemon-reload && systemctl start acme-sh.service
```

Seemingly we can't `systemctl enable` a Quadlet service because it's dynamically generated from the container unit, but since we've got `WantedBy` set to `default.target` in the container unit, that should ensure the container starts automatically at boot anyway.

### Enable Podman auto-update to update the base container
One of my other favourite features of Podman is native support for automatic container updates. Previously in Docker I'd have done this with something like Watchtower, which is its own container that requires mounting the `docker.sock` -- something which involves adding far too much complexity and attack surface for something which could just be a native feature. In Podman, it is.

Any container which is labeled `io.containers.autoupdate=registry` (as we've done to ours in the container unit above) will be automatically updated on a schedule from the upstream registry.

To make this happen, we just need to enable `podman-auto-update.timer`:
```sh
systemctl enable --now podman-auto-update.timer
```

### Using the certs
As with Certbot, `acme.sh` will output our certificate into a familiar directory structure, and we can use these certificates in other tooling by pointing at this directory, or copying the certs elsewhere if more complex permission management is needed.

As a brief example, here is a partial snippet showing how the certs could be used in an `nginx` config:
```text
server {
    [...]

    ssl_certificate /etc/acme.sh/example.infected.systems_ecc/fullchain.cer;
    ssl_certificate_key /etc/acme.sh/example.infected.systems_ecc/example.infected.systems.key;
    
    [...]
}
```

### Caveats
Hopefully the info here helps someone at some point, but I wanted to add some usual caveats to this post.
* This post is very homelab-focused. It's probably not something you want to do in an enterprise setting.
* Depending on your threat model, I don't necessarily recommend using containers with the `:latest` tag and pulling updates to them automatically. For a more conservative approach, since `acme.sh` has no external dependencies, it would be possible to download and pin a "known-reviewed" version of the code for deployment across your infrastructure.
* You will notice that there is no logic in this post to restart the "destination" service if any certificates get renewed. In practice, I run all my lab services with automatic updates and reboots enabled at the OS level, and I find this causes frequent enough restarts that I never see a situation with services continuing to serve an already-expired cert. But YMMV!
