+++
title = 'Static IPv6 config with cloud-init on Raspberry Pi OS'
date = 2026-06-18T22:15:00Z
draft = false
summary = "Documenting more quirks that nobody else documents because they don't put themselves through the pain of an IPv6-only home network like I do."
tags = ['linux', 'ipv6', 'networking', 'raspberrypi']
+++

I recently had some issues with quirks relating to my IPv6-only network when trying to set up an AirPlay sink on Raspberry Pi OS. I struggled to find info relating to the IPv6-only bit specifically, so I've tried to collate some of the issues I had here in the hope they're helpful.

All of the below was done using Raspberry Pi OS Lite Trixie (Debian 13).

## Issues I faced

### New hotness
Raspberry Pi OS now uses [cloud-init](https://docs.cloud-init.io/en/latest/index.html) to configure networking, rather than the old `wpa-supplicant` method.

This is actually good for us since it gives us the very IPv6-friendly powers of `cloud-init`, but it does mean mostly all Pi related networking initial-setup guides floating around are out of date now.

### Confusingly named config keys
If you want to do SLAAC in `cloud-init` then apparently `dhcp6: true` is the setting that you want, even though SLAAC and DHCPv6 are two different technologies.

### Inability to mix-and-match SLAAC & static configs
I couldn't manage to get Raspberry Pi OS to use both SLAAC **and** statically assign an address at the same time, despite being fairly sure I've done this with `cloud-init`/`netplan` in the past.

My non-ideal solution has been to hard-code the gateway and DNS servers into the config as below.

### One-time run of initial network config
While the console output during boot suggests that `cloud-init` runs on every boot, I think the initial network config may only run once on the first boot after imaging the system.

This means that if you mess this config up then it's honestly easiest to just re-image Raspberry Pi OS again. It doesn't seem to be the case that you can update this file in `/boot` after first boot to update the networking config. After first boot, the network config lives in `/etc/netplan` and you have to update it there using [netplan](https://netplan.io/) syntax.

(Yes, i'm sure there's some way to force `cloud-init` to re-run the networking config after initial setup, but it might break other stuff and I'm lazy.)

## My working config

So, to configure my Pi statically on my IPv6-only network, I write the Raspberry Pi OS image to disk and then add the following contents to the `network-config` file on the `boot` partition:

```yaml
network:
  version: 2
  wifis:
    wlan0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 2001:db8:cafe:1234::abcd/64
      routes:
        - to: default
          via: "2001:db8:cafe:1234::1"
      nameservers:
        search: [ "home.arpa" ]
        addresses: [ "2001:8b0:6464::1", "2001:8b0:6464::2" ]
      regulatory-domain: "GB"
      access-points:
        "MyNetwork_v6o_nomap":
          password: "7df640a8589662e0107b068811c9333b86484a908250a742a91fb1cdd5e2aecd"
      optional: true
```

If you're using Wi-Fi as above, the `password` field is a standard WPA2 PSK derivation. If you're using [Raspberry Pi Imager](https://www.raspberrypi.com/software/) then this field will be pre-calculated for you if you enter your SSID and password while writing the SD card.

Alternatively, we can implement the same [logic](https://github.com/raspberrypi/rpi-imager/blob/fc40601220ef8f2f676c00919e01ffa84f4572d7/src/customization_generator.cpp#L21) with a one-line Python function like this:

```sh
python3 -c "import hashlib,sys; print(hashlib.pbkdf2_hmac('sha1', sys.argv[1].encode(), sys.argv[2].encode(), 4096, 32).hex())" "YOURWIFIPASSWORD" "YOURWIFISSID"
```

**Note:** If you want to configure an Ethernet connection, you can substitute the `wifis.wlan0` key above for `ethernets.eth0`, or you can include both if you want to configure both interfaces.

## Side-note: Major love for Shairport Sync

I mentioned at the top of the post that what I was trying to do here was configure my Pi as an AirPlay sink.

I've been really impressed with the Shairport Sync project for this since these two commands are genuinely all that's needed on Raspberry Pi OS to configure a fully-working AirPlay sink that's discoverable from any Apple device or anything modern using Pipewire + ROAP:

```sh
sudo apt install -y shairport-sync
sudo systemctl enable --now shairport-sync.service
```

This "just works" even on an IPv6-only network and hooks into the already-available audio and Avahi backends on Raspberry Pi OS Lite without any additional config.
