+++
title = 'Connecting to Tor from IPv6-only clients'
date = 2024-12-05T19:15:00Z
draft = false
summary = "A workaround to allow IPv6-only clients to connect to the Tor network."
tags = ['tor', 'networking', 'ipv6']
+++

{{< box important >}}
**Warning:** It's possible that there are good traffic-analysis-resistance reasons why the Tor Project haven't enabled the option below by default. If you rely on Tor in a hostile network or territory, I can't recommend setting the option discussed below without doing additional research.
{{< /box >}}

As an addendum to my recent post about [running an IPv6-only network](/posts/2024-12-01-no-nat-november), I wanted to share some things I learned recently about connecting to Tor from an IPv6-only host.

By default, Tor will hang at the bootstrapping stage on IPv6-only networks without a CLAT in place. This applies to both the CLI Tor client, and to the Tor Browser. I think this is down to a hard-coded preference to use IPv4 addresses over IPv6 addresses during the bootstrapping sequence.

The Tor Project have been working on IPv6 support for some time now. Seemingly the client defaults to using IPv6 [as of May 2023](https://gitlab.com/torproject/tor/-/commit/ffb764949e7c1699af715298ce65279a2ee5df6e), so it's a bit of a surprise that this fails entirely when we're IPv6-only, but I guess most of the focus so far has been on making it work on dual-stacked setups.

There's an option that can be enabled in the configuration that fixes this behaviour and lets us connect even on an IPv6-only host.

By setting the following option in our `torrc` file:

```text
ClientPreferIPv6ORPort 1
```

We can get Tor working on an IPv6-only client. Adding this option and restarting Tor is all that was required for me.

I'm currently using this method to host the `.onion` address for this blog. You can visit it using the `.onion` link at the bottom of this page, but it should also send the `Onion-Location` header allowing Tor Browser users to be redirected to it automatically.

### Useful Links
* [Tor Forum post recommending this solution](https://forum.torproject.org/t/tor-browser-cannot-bootstrap-on-ipv6-only-networks/13301/8)
* [Tor GitLab issue - 'default clients, including tor browser, fail to bootstrap on an ipv6-only network'](https://gitlab.torproject.org/tpo/core/tor/-/issues/40913)
* [Tor GitLab issue - 'Add config to prefer IPV6 Address than IPV4'](https://gitlab.torproject.org/tpo/core/tor/-/issues/40838)
* [Tor Blog from 2021 on 'The State of IPv6 support on the Tor network](https://blog.torproject.org/state-of-ipv6-support-tor-network/)

### Addendum: IPv6 bridges and the Tor Network
At this time, while there seems to be a [decent amount of focus from the Tor Project on ensuring IPv6-capable relays](https://blog.torproject.org/state-of-ipv6-support-tor-network/), there are (from what I can tell) relatively few IPv6-capable bridges.

I think this is down to the fact that the Tor client isn't able to listen on both IPv4 and IPv6 when setting up an `obfs4` bridge. It can listen on one or the other, but not both at the same time. This is being [tracked in this Tor GitLab issue](https://gitlab.torproject.org/tpo/core/tor/-/issues/40885).

I think this is leading to Tor bridge operators to choose to set their bridges up with IPv4, as that (probably) allows the bridge to have a bigger impact helping censored clients reach the network. This is the same choice I made myself when I set one up recently. Unfortunately, that has the downside of making the pool of IPv6 bridges much smaller, which might lead to an elevated risk for censored users who really _need_ to use an IPv6 bridge to connect.

There's an [open PR to fix this behaviour](https://gitlab.torproject.org/tpo/core/tor/-/merge_requests/786) so hopefully it gets merged soon.
