+++
title = 'Working around the IPv6-only RDNSS expiry bug affecting macOS and iOS'
date = 2024-12-18T10:30:00Z
draft = false
summary = "If you find your networking broken when waking from sleep on macOS/iOS when on an IPv6-only network, this fix might help you."
tags = ['macos', 'ios', 'networking', 'ipv6']
+++

I've been on a bit of a journey recently related to IPv6-only networking, and wanted to share a fix I had to apply to smooth out the experience on Apple devices.

If you've deployed an IPv6-only or IPv6-mostly network and you find your Apple devices waking from sleep and reporting that their network connectivity has broken, this is probably the same problem you're seeing.

I wanted to write about my solution for this bug since I've seen a few people mention being affected by it but haven't seen anyone post any workarounds publicly yet.

## The Bug

It seems that what's going on here arises from a situation where the RDNSS entries (DNS entries which the host has learned via IPv6 Router Advertisements) can expire while the host is in a low power state. Often these seem to be sent with a default lifetime of about 1800 seconds. It's quite common that we'll have hosts that enter a low power or sleep state for more than 1800 seconds, so this is very easy to trigger.

On a dual stack network, this bug wouldn't cause any issues, because the host would wake back up and simply carry on, happily falling back to using the IPv4 nameservers it learned from DHCPv4. But when we're operating in IPv6-only mode, including if we're on an IPv6-mostly network, this bug causes the host to wake up, discover it has no DNS servers available on the network link it's connected to, and mark the connection as broken. On iOS this means the device often falls back to a cellular connection, while on macOS it just means the network link appears completely broken until Wi-Fi is toggled on/off.

This bug isn't exactly new either. It's referenced on slide 13 of [this presentation given by Google Engineer Jen Linkova](https://datatracker.ietf.org/meeting/118/materials/slides-118-v6ops-jen-linkova-turning-ipv4-off-short-version-slides-118-v6ops-jen-linkova-turning-ipv4-off-short-version) at IETF 118 back in 2023:

![Jen's slide showing a reference to users facing this issue](slide.png)

It's also very reproducible. I've been able to reproduce the same bug with the default configs of three different router advertisement daemons - `rad`, `radvd`, and `corerad`.

I'm not really sure whose responsibility this bug is. I think it probably lies with Apple, as a device waking back up from sleep should probably try and re-learn its RDNSS servers via RA or RS if it discovers they've timed out. I did try and report this to them, but their bug reporting channels are extremely opaque to end-users so I have no idea if I was just shouting into the void.

So with that in mind, I wanted to write up the fix that I have that works for now.

## The Fix

We can fix this by extending the default lifetime for RDNSS advertisements in the config for our router advertisement daemon.

In my configs, I extend this to 604800 seconds (or 1 week). That's quite a substantial increase over the default of around 1800 seconds, but changing DNS servers probably isn't something that home users are doing very often, and it's long enough to cover a device which might be in a low power state for several days before being woken back up.

## The Fix - `rad`

In my previous post, I talked about [building an OpenBSD router for a home network focused around IPv6](/posts/2024-12-07-building-an-ipv6-focused-openbsd-home-router).

In that post, I used `rad` as the router advertisement daemon which is built into OpenBSD.

In our `rad` config, we can extend the RDNSS expiry time to patch over this issue by adding a `lifetime` entry to the `dns` section of the config.

For example (this is a snippet and not a fully functional config):

```sh
dns {
  lifetime 604800
}
```

For a fully functional `rad.conf`, see [my previous post](/posts/2024-12-07-building-an-ipv6-focused-openbsd-home-router).

## The Fix - `radvd`

On Linux, pfSense and OPNsense, it's more common to see the `radvd` daemon being used.

We can fix the issue in our `radvd` config as follows (this is a snippet and not a fully functional config):

```sh
interface vlan123 {
  RDNSS 2001:db8:cafe:beef::1 {
    AdvRDNSSLifetime 604800;
  };
};
```

## The Fix - `corerad`

I'm a big fan of [CoreRAD](https://corerad.net/) personally. It's modern-feeling and written in Go, and seems to move at a faster pace than `radvd`.

We can fix the issue in our `corerad` config as follows (this is a snippet and not a fully functional config):

```toml
[[interfaces]]
  [[interfaces.rdnss]]
  lifetime = "604800s"
```

For a fully functional `corerad` config, see [this one in my Pinewall project repository](https://github.com/alexhaydock/pinewall/blob/191a3643047aed84c72ee36c2daefa6d5c6aaead/config/etc/corerad/config.toml). I haven't written about Pinewall yet (my image-based Alpine Linux router spin), but I'll probably write a post about that soon.

## Potential Downsides
I've been trialing this fix in (home!) production for a while across all 3 of the above router advertisement daemons and haven't seen any downsides yet. I also can't really imagine any that would really arise. If you can think of any, please do let me know!

We can also implement this fix while still staying in spec with [RFC 8106](https://datatracker.ietf.org/doc/html/rfc8106), which defines compliant values for the RDNSS lifetime. It dictates that the lifetime SHOULD be set to a value of _at least_ 3 times the value of `MaxRtrAdvInterval` (which is defined in [RFC 4861](https://www.rfc-editor.org/rfc/rfc4861) as being a maximum of 1800 seconds). So for those counting - an RDNSS timeout of 5400 seconds and above would be within RFC 8106 spec on any network.

So our long timeout is within spec, and ought to ensure that the laptop we leave in sleep mode in a bag for 5 days still wakes up without any annoying network interruption.

Hopefully this fix helps some folk!
