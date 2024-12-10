+++
title = 'Building an IPv6-focused OpenBSD home router'
date = 2024-12-10T07:00:00Z
draft = false
summary = "A guide to configuring an OpenBSD home router, with a focus on IPv6 and transition technologies."
tags = ['openbsd', 'networking', 'ipv6']
+++

As part of my recent adventure [running an IPv6-only network for a month](/posts/2024-12-01-no-nat-november), I ended up setting up a full IPv6-mostly home router setup using OpenBSD.

While doing this, I noticed that many of the guides online for doing this with OpenBSD are great, but are very focused on IPv4. Even the [Building a Router](https://www.openbsd.org/faq/pf/example1.html) page on OpenBSD's website doesn't seem to reference IPv6 at all.

So in this guide, I wanted to lay out how I was able to use OpenBSD to set up a fully IPv6-native home router with support for all the latest 464XLAT-related goodness required to build the kind of IPv6-mostly network I talked about in my recent post.

Working versions of the configs used in this guide are available on GitHub in my [openbsd-ipv6-focused-home-router](https://github.com/alexhaydock/openbsd-ipv6-focused-home-router) repo. I'm no OpenBSD expert so if you find things in here which could be improved then feel free to open issues in that repo to suggest improvements!

## IPv6-mostly Support
This matrix shows the IPv6 and IPv6-mostly support focused on in this guide, and which OpenBSD components are helping us achieve those goals:

| Technology | OpenBSD Component |
|---|---|
| IPv6 from our ISP | PPPoE config |
| NAT64 PLAT | `pf` |
| DNS64 | Unbound |
| PREF64 | `rad` |
| DHCPv4 Option 108 | `dhcpd` |

## Why OpenBSD over something like Linux?
There are plenty of reasons to use Linux for routing, especially if you're more familiar with it. My primary router is Linux based and you can [find that on GitHub](https://github.com/alexhaydock/pinewall) too. It gets built into an image based deployment by CI/CD processes so if that sounds interesting, check it out!

In this case, I opted for OpenBSD for one specific reason, which is that you can implement a NAT64 gateway (aka PLAT) in a single line of OpenBSD `pf`. We'll get to that as the article goes on, but having wrestled with Jool/Tayga on Linux (which require kernel modules built using DKMS to work) the single line of `pf` is a total breath of fresh air. If you have an ISP who hosts a NAT64 gateway for you, this is less of a concern, but if you don't, then OpenBSD is a great option.

I'm also a big fan of the fact that you can implement everything in this guide in the OpenBSD base system without adding a single extra package.

## Base system
I started with OpenBSD 7.6 for this guide. I'll leave installation as an exercise to the reader, since there are plenty of installation guides out there. I used the regular `install76.iso` and opted to remove the `x*` and `games*` sets when prompted at the set selection screen.

## Basic interface configuration
In this example, I will be building a simple two-interface WAN/LAN config with interfaces as follows:
* `vi0` - WAN interface
* `vi1` - LAN interface
* `pppoe0` - virtual PPoE interface for dialing my ISP, backed by `vi0`

OpenBSD's interface configuration is very simple. As an example, we can configure an IPv6-capable interface like this - where `vi1` is the name of our downstream LAN interface:

### `/etc/hostname.vi1`

```text
inet 192.168.100.1 255.255.255.0
inet6 2001:db8:cafe:beef::1/64
```

## PPPoE interface configuration
If we use PPPoE to connect to our ISP, we can configure that using a similar method to above, with a few added lines. This config works to provide full IPv6-support from my ISP:

### `/etc/hostname.pppoe0`

```text
inet 0.0.0.0 255.255.255.255 NONE mtu 1492 pppoedev vio0 authproto chap authname 'youruser@account' authkey 'YOURAUTHKEY' up
dest 0.0.0.1
inet6 2001:db8:cafe::1 64
!/sbin/route add default -ifp pppoe0 0.0.0.1
!/sbin/route add -inet6 default -ifp pppoe0 fe80::%pppoe0
```

In my case, I have a static `/48` from my ISP, so I've statically assigned the `::1` address from the first `/64` in my `/48` to the router in this file here on the `inet` line. This will become the reachable IPv6 address of this router itself from the WAN. If your ISP uses prefix delegation to rotate prefixes, you might need to change some of these lines.

In the above example, the first line of our config specifies `vi0` as the upstream physical interface that will be used for dialing the internet connection. To go with this, we need some config to bring up that interface. I use the following simple config to set the MTU and bring the interface up:

### `/etc/hostname.vi0`

```text
up mtu 1500
```

## Enable packet forwarding
Pretty basic, but we can't forget to set the `sysctl` settings to allow packet forwarding, turning our host into a router:

### `/etc/sysctl.conf`
```ini
net.inet.ip.forwarding=1
net.inet6.ip6.forwarding=1
```

## Firewall config (`pf.conf`)
I'll leave most of the `pf` config for you to [check out in the GitHub repo directly](https://github.com/alexhaydock/openbsd-ipv6-focused-home-router/blob/main/etc/pf.conf) and follow other guides or tutorials. It's deliberately basic and generic for people to adapt further.

In this post I'll just focus on calling out the things which are interesting to us from an IPv6 perspective.

## Bufferbloat shaping
Before we launch into the IPv6-focused featureset, I wanted to call out another feature of OpenBSD `pf` that I really like. The bufferbloat shaping options are super simple compared to alternatives like `tc` on Linux.

An example which tends to get me top marks in all [the various bufferbloat testers](https://www.waveform.com/tools/bufferbloat) online, and which is tuned for my VDSL connection that runs at approx 69 mbps down / 16 mbps up:

```text
[...]
queue isp_d on $lan flows 1024 bandwidth 68M max 69M qlimit 1024 default
queue isp_u on $wan flows 1024 bandwidth 15M max 16M qlimit 1024 default
[...]
```

## NAT64 gateway (PLAT)
Our first bit of IPv6-mostly magic involves the NAT64 gateway config within our `pf` config.

Setting up a NAT64 PLAT in OpenBSD `pf` looks like this:

### `/etc/pf.conf`

```text
[...]
pass in on $lan inet6 from any to 64:ff9b::/96 af-to inet from (egress:0)
[...]
```

In this example, `(egress:0)` is OpenBSD `pf` speak for the first IPv4 address (`:0`) of the interface which has the default route applied (`egress`). In our case, that means NAT64 traffic will be NAT'ed to the first IPv4 address our ISP gives us on our WAN link. This is probably what you want too, but if your needs are more specific then you can tune this line as you see fit.

But overall, it really is that simple to set up. Amazing, right?

## DNS64 server
To go with our NAT64 gateway, it's useful for us to have a DNS64 server.

We don't strictly have to do this ourselves. Since we're using the well-known NAT64 prefix of `64:ff9b::/96` for our gateway, we could delegate this to a public DNS64-capable server, such as [Google Public DNS64](https://developers.google.com/speed/public-dns/docs/dns64). But it's nice to host it ourselves.

The unbound config snippet below is what we need to add to the `server:` directive in the config file for our Unbound DNS resolver to allow it to synthesise DNS64 AAAA records. Unbound also automatically adds the `ipv4only.arpa` records we need in order for clients to be able to discover the NAT64 prefix using [RFC 7050](https://www.rfc-editor.org/rfc/rfc7050).

The use of `validator` in this config means we're also preserving DNSSEC capabilities, as Unbound itself will validate DNSSEC. You can test that this is working at [dnscheck.tools](https://www.dnscheck.tools/).

### `/var/unbound/etc/unbound.conf`
```text
[...]
module-config: "dns64 validator iterator"
[...]
```

## IPv6 Router Advertisements & PREF64
To configure IPv6 Router Advertisements and advertise IPv6 prefixes on our network for clients to adopt via SLAAC, we can use `rad`, which is also built into OpenBSD.

In my case, since I have the `/48` from my ISP, I simply pick `/64` allocations out of this for my downstream VLANs. I assign those in the `/etc/hostname.vi*` files as covered above. With `rad` as our RA daemon, it's smart enough to do the rest simply by virtue of us feeding it the interface name.

### `/etc/rad.conf`

```sh
# Create a prefix to advertise to using Router Advertisements
#
# We don't need to specify the prefix to advertise because rad
# will infer it from the prefix assigned to the interface we
# assign here (yes, this is the opposite of how dhcpd is configured)
interface vio1
default router yes
dns {
  nameserver {
    # Advertise this router as the DNS server,
    # just like we do for IPv4 in the dhcpcd config
    2001:db8:cafe:beef::1
  }
  search {
    # Use the RFC 8375 special-use domain designated
    # specifically for home networks
    home.arpa
  }
}

# Advertise the NAT64 prefix available on this network
# using PREF64, as per RFC 8781
nat64 prefix 64:ff9b::/96
```

As you can see, the final line is all that's required to advertise our NAT64 prefix via PREF64 ([RFC 8781](https://www.rfc-editor.org/rfc/rfc8781)), allowing clients to discover it via Router Advertisements. Strictly speaking we don't _need_ this, since clients can already discover our prefix via our DNS64 server using RFC 7050, but it's nice to have both methods available.

## DHCPv4 Op108 - The IPv6-mostly Magic
I made a lot of noise in my last post about the virtues of going IPv6-mostly. In brief, that refers to using a DHCPv4 server to send a particular flag informing clients on the network that they should switch into an IPv6-only mode of operation if they're capable of it. This lets us operate a dual-stack network with clients switching to IPv6-only automatically once they become capable, allowing us to wind down IPv4 capabilities gradually, and deprecate them when they're no longer needed.

The flag in question is the `v6-only-preferred` flag, aka DHCPv4 Option 108, or [RFC 8925](https://www.rfc-editor.org/rfc/rfc8925.html), and this is fully supported by OpenBSD's `dhcpd` DHCPv4 daemon.

Setting up a full IPv4 subnet with Op108 within `dhcpd` looks like this:

### `/etc/dhcpd.conf`

```sh
# Create a DHCPv4 range for a specific subnet
#
# We don't need to specify an interface here, as dhcpd
# will infer which interface to use based on the subnet
# we provide
subnet 192.168.100.0 netmask 255.255.255.0 {
    # Advertise this router as the IPv4 gateway 
    option routers 192.168.100.1;

    # Define DHCPv4 range
    range 192.168.100.100 192.168.100.200;

    # Advertise this router as the DNS server,
    # just like we do for IPv6 in the rad config
    option domain-name-servers 192.168.100.1;

    # Use the RFC 8375 special-use domain reserved
    # specifically for home networks
    option domain-name "home.arpa";

    # Send DHCP Option 108 (RFC 8925) to tell clients
    # we're on a v6-only-preferred (IPv6-mostly) network
    option ipv6-only-preferred 900;
}
```

## Updating via `syspatch`
If, like me, you're more familiar with Linux than OpenBSD, you may want to familiarise yourself with `syspatch` at this point, which is how security updates are applied to the base system.

The unofficial OpenBSD Handbook [has a useful page on syspatch](https://www.openbsdhandbook.com/system_management/updates/).

## Debugging with `pflog`
One of my favourite things about OpenBSD as a firewall is `pflog`. The `pflog` interface is a virtual network interface which allows you to inspect packets which have been logged by `pf`.

My example `pf.conf` doesn't have any rules with `log` statements in, but debugging the firewall is as simple as adding a `log` statement to the rules you want to debug, and then using `tcpdump` to inspect the packets hitting the rule:

```sh
tcpdump -n -e -ttt -i pflog0
```

Thankfully `tcpdump` is also included in the OpenBSD base system, so we can even get this far without installing a single package.

## Questions / comments / complaints?
As mentioned, I'm no OpenBSD expert. Linux is definitely more my realm. I just wanted to put a guide of this type out there since I couldn't find anything like this when I was searching for myself.

If I've missed anything obvious or something is confusing, please [open an issue on the GitHub repo](https://github.com/alexhaydock/openbsd-ipv6-focused-home-router/issues) or get in touch!

Happy routing!
