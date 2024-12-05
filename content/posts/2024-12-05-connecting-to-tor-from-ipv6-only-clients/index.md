+++
title = 'Connecting to Tor from IPv6-only clients'
date = 2024-12-05T19:15:00Z
draft = false
summary = "A workaround to allow IPv6-only clients to connect to the Tor network."
tags = ['tor', 'networking', 'ipv6']
+++

{{< box important >}}
**Warning:** It's possible that there are good censorship-resistance reasons why the config option discussed in this post isn't enabled by default. If you rely on Tor in a hostile network or territory, I can't recommend blindly setting the option discussed below.
{{< /box >}}

As an addendum to my recent post about [running an IPv6-only network](/posts/2024-12-01-no-nat-november), I wanted to share some things I learned recently about connecting to Tor from an IPv6-only host.

By default, Tor will hang at the bootstrapping stage on IPv6-only networks without a CLAT in place. This applies to both the CLI Tor client, and to the Tor Browser. I think this is down to a hard-coded preference to use IPv4 addresses over IPv6 addresses during the bootstrapping sequence.

The Tor Project have been working on IPv6 support for some time now. Seemingly the client defaults to using IPv6 [as of Tor Browser 48](https://gitlab.torproject.org/tpo/applications/tor-browser/-/issues/41742#note_2908117), so it's a bit of a surprise that this fails entirely when we're IPv6-only, but I guess most of the focus so far has been on making it work on dual-stacked setups.

There's an option that can be enabled in the configuration that fixes this behaviour and lets us connect even on an IPv6-only host.

By setting the following option in our `torrc` file:

```
ClientPreferIPv6ORPort 1
```

We can get Tor working on an IPv6-only client. Adding this option and restarting Tor is all that was required for me.

On a Linux host, this file is probably at:
```
/etc/tor/torrc
```

I'm currently using this method to host the `.onion` address for this blog. You can visit it using the `.onion` link at the bottom of this page, but it should also send the `Onion-Location` header allowing Tor Browser users to be redirected to it automatically.

### Useful Links
* [Tor Forum post recommending this solution](https://forum.torproject.org/t/tor-browser-cannot-bootstrap-on-ipv6-only-networks/13301/8)
* [Tor GitLab issue - 'default clients, including tor browser, fail to bootstrap on an ipv6-only network'](https://gitlab.torproject.org/tpo/core/tor/-/issues/40913)
* [Tor GitLab issue - 'Add config to prefer IPV6 Address than IPV4'](https://gitlab.torproject.org/tpo/core/tor/-/issues/40838)
* [Tor Blog from 2021 on 'The State of IPv6 support on the Tor network](https://blog.torproject.org/state-of-ipv6-support-tor-network/)
