+++
title = 'No NAT November: My Month Without IPv4'
date = 2024-12-01T18:00:00Z
draft = false
+++

## Day 0: Challenge accepted
Near the beginning of November, nixCraft posted this challenge on Mastodon, daring people to take the No NAT November challenge and disable IPv4 for the month, relying only on IPv6:

![nixCraft's No NAT November challenge post on Mastodon](ChallengeAccepted.png)

With the challenge laid out like that, I couldn't resist.

## Conclusions
I know this is quite a long and technical post, so I figured it makes sense to put a conclusion about my experience near the beginning.

So, after a month, what do I think? Do I recommend that you go and disable IPv4 in your home network and go IPv6-only?

Well no. Not quite yet.

But you absolutely should go IPv6-_mostly_. Which is something we'll get into in quite some depth as this post goes on. It's really a win-win, and I'll be deploying all my networks as IPv6-mostly from now onwards.

## Why try this?
In this post, I don't really want to get into the detail of why IPv6 is an improvement over IPv4. The initial RFC was ratified in 1998 and there's been over 2 decades of content generated about the benefits it brings since then. IPv6 is the current version of the IP protocol and IPv4 is legacy. I consider that a settled matter.

The key point here is that the 'default' IPv6 capable end-user network is a dual stack network (i.e. one which deploys IPv4 alongside IPv6). This might work nice and transparently from the perspective of end-users, but running two separate network stacks with different addressing scheme and configuration alongside each other means we've now got 2x as many things to consider and 2x as much admin and maintenance work to do.

I know some network administrators use this increased maintenance burden as a reason to justify not having to learn or deploy IPv6 in the first place, but what if we used it as a reason to disable IPv4 instead?

And since there's no faster way to learn the downsides of something than simply just doing it, so began my journey of spending November on a single-stack IPv6-only network.

## Scope
So throughout the month of November, I decided that I would disable IPv4 connectivity on my main home network and see what broke, and whether there were any steps I could take to work around the breakage or fix it.

Throughout the process, I wanted to follow an iterative approach. I would first take the network back to pure IPv6-only, without even any transitional technologies in place. And then I would add in the transitional technologies until I determined whether I could live without IPv4 connectivity long-term.

Please note that throughout this post I'm really **only focusing on the challenges of going IPv6-only from a home networking standpoint**, rather than anything at an enterprise or carrier level. Though you may be interested to note from the enterprise standpoint that [Microsoft were transitioning their corporate network to be IPv6-only as early as 2017](https://labs.ripe.net/author/mirjam/ipv6-only-at-microsoft/). And from the carrier standpoint, Sky appear to be [actively working on IPv6-only deployments for their UK home broadband customers](https://www.ipv6.org.uk/wp-content/uploads/2024/10/02_Sky-UK-MAP-T-UK-IPv6-Council-Nov2024.pdf).

## Day 1: Pure IPv6-only (without transitional tech)
For this first stage, I simulated going IPv6-only by disabling the DHCPv4 server on my router.

So... what broke?

Well - unfortunately quite a lot. Including some real showstoppers.

### Desktop OS support
At a platform level, every desktop operating system I tried offered seamless support for operating on an IPv6-only network. I was a little surprised actually, since when I've tried this in the past, I've seen operating systems report a lack of IPv4 as if the network was suffering problems or was unconnectable.

I was pleasantly surprised to see all my devices, across macOS Sequoia, Win 11, Ubuntu 24.04, and Fedora 41 seamlessly accepting without any protest that my network had no IPv4 connectivity, all dutifully setting up the connection with single-stack IPv6.

### Mobile OS support
The only devices I have in this category are iOS devices and they handled the situation similarly flawlessly.

### Embedded device support
Things aren't quite so rosy on the embedded front unfortunately.

I tried a Nintendo Switch and it completely refused to connect to the network without a working IPv4 stack:

![Screenshot of Nintendo Switch screen, failing to connect to the network](MoreLikeNintendont.jpg)

That didn't surprise me hugely, as Nintendo have historically lagged behind a bit in terms of networking capabilities, but what did disappoint me quite a bit was the way the Steam Deck behaves.

As a Linux-based device with a recent kernel and a full desktop environment available, I had quite hoped the Steam Deck would act much like my other desktop devices. Unfortunately it's even more frustrating than the Switch, because it actually does set up a full IPv6 stack - and even shows the IP in the network connection settings menu - but overall it seems to decide that the lack of IPv4 connectivity means the network isn't working. It just gets stuck 'Connecting' for a while, before eventually failing altogether:

![Screenshot of a Steam Deck network settings page, showing it having retrieved an IPv6 address but still failing to connect](DeckDisappointment.jpg)

Surprisingly, the Deck reacted the same way in desktop mode. Having partially-working network support also seemed to cause the Steam Deck to get very confused when shutting down in either mode, causing it to hang for a long time on the shutdown screen. All of which was a touch disappointing.

Having exhausted my collection of current-gen consoles, the other obvious problem I encountered right away is that despite being able to route IPv6 traffic without any concerns, all of my home networking gear seems to be IPv4-only when it comes to management interfaces.

Most of my network is made up of TP-Link access points [like this one](https://www.tp-link.com/uk/business-networking/ceiling-mount-ap/eap245/) and their cheap VLAN-capable switches [like this one](https://www.tp-link.com/us/business-networking/easy-smart-switch/tl-sg116e/). Generally I wouldn't hesitate to recommend these to anyone, as they're very cost-effective VLAN-aware pieces of equipment that are great for a home environment.

Unfortunately, as seems to be a common theme with home networking gear, the management interface configurability is a bit lacking and restricted to IPv4 only:

![TP-Link switch interface showing the ability to only configure the switch for IPv4 and not IPv6](v4OnlySwitchMGMT.png)

This isn't particularly a huge problem since I put these management interfaces on a dedicated network anyway for security reasons. But it's one that I thought would be useful to call out, since it might affect you if you're trying to opt for a simpler network design. Being unable to manage any of your switches or access points once you remove the IPv4 addresses from your clients could be a real pain.

### Web service support
Well... this is where things really fall down.

I'm certainly not the biggest fan of the increasing centralisation of the web behind a number of large cloud/CDN providers, but one of the things it has brought us is easy IPv6 'for the masses'. I do think the relative ease of adoption of IPv6 within the interfaces of providers like Cloudflare has led to a huge increase in the overall reachability of the web over IPv6.

Unfortunately, there's still some surprising holdouts. GitHub quite infamously still haven't deployed IPv6. And neither have Reddit, Discord, or Steam. On my pure IPv6 connection these sites simply don't load and plenty of others don't either.

You can get to a _lot_ of the internet over pure IPv6 these days. But all it really takes is for an end user to rely on anything in the list above, and the idea of using a pure IPv6 connection is dead on arrival.

## Day 2: About those IPv6 transition technologies
So it was clear pretty immediately at this point in the challenge that I wasn't going to be able to continue without deploying some level of transitional technology that would allow me to continue to access the services which only operate over IPv4.

Luckily, now with zero working game consoles, I had plenty of free time to investigate.

### 464XLAT
The primary transitional technology that's going to be relevant for home users is going to be 464XLAT. As far as I can tell, 464XLAT is a combination of a number of different concepts which often get referenced interchangeably, such as NAT64 and DNS64. I'll do my best to explain them here.

### NAT64 with DNS64
Broadly, DNS64 works like this:

![Diagram showing the flow of DNS64](Mermaid1.png)

What's happening here is that our IPv6 device makes DNS requests as normal, but to a DNS server which is running in DNS64 mode. This is effectively a normal DNS server speaking the regular DNS protocol, but when in this mode, the server will detect when a domain has only A records and no AAAA records, and will synthesise 'fake' AAAA records for sites in this category.

The synthetic AAAA records sent back by the DNS64 server make use of the fact that the entire IPv4 internet can fit into an IPv6 block which is only `/96` wide. So they're comprised of a prefix, which points to a NAT64 Gateway (also called a PLAT), and a suffix, which is just an encoded version of the IPv4 address.

For example, on my current host `github.com` resolves to:

```
64:ff9b::141a:9cd7
```

Where `64:ff9b::` is the well-known prefix used by many NAT64 implementations, and `141a:9cd7` is simply an encoded version of the A record that `github.com` was returning for me (`20.26.156.215`).

As a random note - If you're interested in decoding a NAT64 mapped address back to the IPv4 literal address it represents, there's a [useful tool here](https://www.whatsmydns.net/ipv6-to-ipv4?q=%3A%3Affff%3A141a%3A9cd7) that can do it if you replace the NAT64 prefix with `::ffff:`. I'll leave the details of why that works for another day, and there's probably many other ways of doing this, but this has been useful to me in the past.

Once we have our encoded AAAA records in our DNS response, our client can act as normal, sending packets to the IPv6 addresses as if they were official AAAA records served by the site itself. Those packets will be routed to the NAT64 gateway which will listen for packets targeting the entire NAT64 prefix (in our case, the whole of `64:ff9b::/96`). When it receives a packet like this, it will use the encoded suffix to decode the IPv4 address the packet is intended for, and will forward it accordingly to the site over IPv4.

Through this process, we're able to get rid of any requirement for IPv4 connectivity anywhere prior to the NAT64 gateway. In terms of our challenge, this allows us to stay IPv4 free on our LAN entirely, and delegate all remaining IPv4 requirements to our NAT64 gateway.

### Wait, NAT64? Isn't that cheating?
At this point, a few of you have probably already objected on the basis that this post is titled 'No NAT November' and I'm busy describing deploying something called **NAT**64 on only the second day of the challenge.

I guess that's a fair complaint, but NAT64 has some useful qualities that set it apart from standard private-IPv4-inside-public-IPv4-outside type home networks (more commonly called NAT44).

The main difference here is that we don't have to host the gateway within our own network. Unlike using NAT44 where the internal IP ranges are usually going to be RFC 1918 private addresses that we can't route over the internet, our IPv6 addresses are globally publicly routable. Which means, in theory, anyone anywhere can host our NAT64 gateway for us.

In my case, I have a very forward-thinking ISP (shoutout to _Andrews & Arnold_ in the UK), and [they host a NAT64 gateway for customers to use, along with DNS64 servers](https://support.aa.net.uk/Server_List). So since all of the burden of doing NAT exists completely outside my network, I'm considering this within the spirit of nixCraft's challenge. If you disagree, please do argue as much as possible about it. It boosts engagement.

For those without such forward-thinking ISPs, there are also [public-facing NAT64 and DNS64 providers](https://nat64.net/public-providers) that you can use. Being in security I can't exactly in good conscience recommend sending all your traffic thorough an un-vetted third party. But they do exist, so I figured I should mention them.

It is also entirely possible to host your own NAT64 gateway, either on your regular firewall/gateway, or on a host elsewhere within your network. This host will need IPv4 connectivity to forward on the packets, and there is a fair learning curve to setting one of these up, but _apalrd's adventures_ on YouTube [has a great guide to doing this on OPNsense](https://www.youtube.com/watch?v=WZSdpY_VgyY).

### NAT64 with CLAT
NAT64 using DNS64 gets us most of the way to having a much happier experience running an IPv6-only LAN. But it doesn't quite get us all the way.

Since DNS64 is based around, well... DNS, it can't help us in situations where we have an app or tool that wants to connect to IPv4 literals (i.e. hard-coded IPv4 addresses without using DNS).

To solve this problem, we can use a CLAT.

A CLAT is an extra layer that an IPv6-only device can implement which will allow it to translate IPv4 packets to IPv6 packets on the fly. This is done using much the same mechanism as DNS64. The packets get rewritten into IPv6 packets with a prefix matching the NAT64 gateway address, and with a suffix matching the encoded IPv4 address of the destination host.

[The RFCs](https://www.rfc-editor.org/rfc/rfc6877) suggest that CLAT stands for _Customer-side Translator_ but that doesn't seem to fit so well, so I prefer to read it as 'Client-Layer Address Translator' as it keeps it straight in my own head where in the flow the translation is actually happening.

The way this works is that a compatible host will set up the local IPv4 stack of the device to use a 'fake' gateway and client IP. Here's an example of what this looks like on iOS:

![A screenshot of iOS's network settings showing an active CLAT](iOSCLAT.jpg)

What's going on here is that the 'Router' represents the fake CLAT gateway, which exists within the device itself. And the 'IP Address' represents the fake endpoint IP that the device has assigned itself.

This allows the device to act like it has a fully normal and functional IPv4 stack, while transparently translating packets in the background to be able to handle an IPv6-only transit layer.

That looks like this and, as you can see, the end result is that we only have IPv6 packets leaving and returning to the device, allowing us to operate quite happily on an IPv6-only network segment:

![Diagram showing how NAT64 works with a CLAT on the client device](Mermaid2.png)

This allows us to effectively deal with applications and other tooling which might expect or require the ability to be able to communicate with hard-coded IPv4 literals.

When using only DNS64, our clients don't really need a way of learning the NAT64 prefix they should be using, because it'll be transparently included in the AAAA responses sent back by the DNS64 server. But now that we've moved into using a CLAT, we're no longer using DNS to look up addresses before connecting to them. So we need a mechanism for our client to learn the prefix that should be prepended to NAT64 packets before sending them out.

There's a few of these, but the two main ones seem to be:
* [RFC 7050](https://www.rfc-editor.org/rfc/rfc7050) - Which allows a client to discover it from a DNS64 server by looking up the special domain `ipv4only.arpa`.
* [RFC 8781](https://www.rfc-editor.org/rfc/rfc8781) - aka PREF64, which allows it to be served to clients on an IPv6 network through Router Advertisements.

Happily, all DNS64 servers I've encountered implement RFC 7050 which means realistically if you're using an operating system that fully supports setting up a CLAT, there's probably no extra work for you to do here if you've also got DNS64 enabled.

### OS-level CLAT support
With that in mind, it's time to talk OS support for using a CLAT.

A CLAT is a complex piece of network engineering which needs to be fairly deeply integrated into the host OS to work _well_, so it requires a fairly forward-thinking implementation on the part of the vendor.

#### Apple
I'm not the world's biggest Apple fan, but honestly their implementation here is the gold standard. 10/10, no notes. All their devices support automatically setting up a CLAT in a way that's transparent to the end-user and they can discover the prefix using either RFC 7050 or 8781. Apple even make this work on the devices where you'd normally expect a vendor to pay less attention, such as the Apple TV and on the HomePod.

Once I deployed my NAT64+DNS64 support, all my Apple devices seamlessly configured CLAT interfaces and worked out of the box with no config required. Right away I can do things like `ping 1.1.1.1` without even thinking, despite the complete lack of IPv4 on the network segment the devices are on.

#### Microsoft
Sadly, the same cannot be said about Windows. Although as of March 2024, [Microsoft have committed to bring CLAT support to Windows 11](https://techcommunity.microsoft.com/blog/networkingblog/windows-11-plans-to-expand-clat-support/4078173), which is great news. Unfortunately, as of Win 11 24H2, it still hasn't landed yet so we may be waiting a bit longer.

#### Linux
In the CLAT space, Linux is... interesting. [clatd](https://github.com/toreanderson/clatd) exists and does see some maintenance, though the only distributions that seem to package it are [Fedora and openSUSE](https://pkgs.org/search/?q=clatd), and neither ship it by default.

I've had mixed results using `clatd`. It's a touch finnicky and seems to get a bit confused when carrying out very regular tasks, such as switching between ethernet and Wi-Fi when docking/undocking a laptop.

I'd like to see something emerge for Linux which is a bit more embedded into the core of the OS and functions a bit more smoothly, like Apple's implementation. There's been an issue open on [systemd's GitHub](https://github.com/systemd/systemd/issues/23674) for a couple of years now asking for something like this. Who knows, maybe we'll see `systemd-clatd` eventually.

## Day 3 - 30: IPv6-only (with transitional tech)
So by Day 3, I still have my IPv6-only network deployed, and I also have NAT64+DNS64 along with CLATs on devices which support them.

At this point, things are far more functional than they were on Day 1. DNS64 is really taking care of almost everything on my Windows and Linux hosts, and on my Apple hosts the CLAT is getting me the rest of the way.

There's still a few things annoyingly broken though, but now that the transitional tech has been deployed, they all revolve around the apps that insist on using IPv4 literals.

A selection of things that I've discovered are still broken on an IPv6 only network with NAT64+DNS64:

| Thing | Why it's still broken |
|---|---|
| Steam | Client relies on IPv4 literals. Broken without a CLAT. |
| Discord WebRTC | Seems to rely on IPv4 literals for setting up calls. Broken without a CLAT. |
| Network device WebUIs | I can't really fix this one. They simply don't support IPv6 on their WebUIs. |
| Steam Deck | Annoyingly broken despite successfully assigning itself an IPv6 address. But I doubt it would work anyway given the Steam client is broken as above. |
| Nintendo Switch | Doesn't seem to connect at all if IPv4 is not available. |

What you'll notice from the above is that it really isn't a particularly long list. It's based on my own workloads so no doubt if you try this you'll find a great number of other things that don't work and are a dealbreaker for your own personal workflow.

But it's quite striking that we're a long long way from the "everything is broken" territory people might instinctively expect when they think about the fallout of disabling IPv4, even when considering systems without a functioning CLAT.

But we're still left in one of two non-ideal situations:
* Waiting for our OS vendor to implement a CLAT; or
* Complaining about individual apps still relying on IPv4, on GitHub issues which are [sometimes over 10 years old](https://github.com/ValveSoftware/steam-for-linux/issues/3372).

Neither of these are particularly great options. But there is an alternative.

As of 2020, there's a shining fix to our predicament available, in the form of IPv6-_mostly_. In order to understand where IPv6-mostly comes from, I can't avoid relaying the wonderful story of its inception, even though I know this post is already far too long.

## How to manage the unmanaged: orchestration by RFC
How would you deal with deploying OS-level config to a fleet of devices?

Some form of config management, you presumably reply. Ansible? Puppet? Salt? Chef? They're all good choices... when you have control over the devices you want to manage with them.

But what if you have a fleet of BYOD employee-owned devices. Devices which are all running a disparate selection of operating systems, versions, and technologies? How do you effectively... manage the unmanaged?

This was the problem faced by Jen Linkova, a Network Engineer at Google, when attempting to disable IPv4 on a fleet of unmanaged devices as part of their corporate network IPv6 transition.

The answer, it turns out, is a stroke of genius.

You simply:
* Author a bunch of IETF RFCs that define a standard for using DHCPv4 messages to reconfigure willing hosts to switch into IPv6-only mode;
* Get those RFCs ratified;
* Get support to send these messages landed in all the major DHCPv4 servers;
* Get the functionality to deal with these messages landed in all the major OSes;
* Enjoy your new-found configuration powers over the devices on your network.

Move over orchestration by Ansible Playbook. We have orchestration by RFC now.

Jen lays all this out in their presentation titled [Mission ~~Im~~Possible - Turning IPv4 Off in an Enterprise Network](https://www.youtube.com/watch?v=UTRsi6mbAWM) which is extremely entertaining and well worth a watch!

Jen and team are responsible for a number of relevant RFCs in this space, but the one that's most interesting to us right now is [RFC 8925](https://www.rfc-editor.org/rfc/rfc8925.html) which describes the new DHCPv4 "Option 108", aka "IPv6-Only Preferred".

## DHCPv4 Option 108: IPv6-Only Preferred
At its core, this is a deceptively simple concept. The idea is that you continue to deploy your network dual-stack with both IPv4 and IPv6 support as before, but you instruct clients which are capable of operating in an IPv6-only mode to switch into an IPv6-only mode.

IPv6-Only Preferred generally relies on having IPv6 transition technologies in place so that when the client switches into IPv6-only mode, it is not cut off from the IPv4 internet entirely. But that's not a strict requirement. You _could_ enable this on a network without any NAT64 access at all. But you probably don't want to, so bear that in mind.

Clients which support operating in IPv6-only mode and see a DHCPv4 server sending Option 108 will dutifully switch into that mode and avoid taking an IPv4 address from the DHCPv4 server, while clients that are incapable of operating in IPv6-only mode will set themselves up as dual-stack clients just as they would have done previously. Clients which are too old to even understand the option will simply ignore it and carry on taking an IPv4 address as they always have.

With this, we create what's called an IPv6-_mostly_ network. Effectively the technological equivalent of having our cake and eating it. In this configuration, the network is dual-stacked, but clients will only take an IPv4 address if they _need_ one. This allows us to watch our DHCPv4 lease table tick down in size until the day finally comes when we can disable IPv4 entirely.

## IPv6-mostly - your road to (eventual) single-stack-success
IPv6-mostly networks really end up being the best of all worlds. I would revisit the table from the prior section and compare an IPv6-only+464XLAT setup with an IPv6-mostly setup, but the truth of the matter is that on IPv6-mostly I haven't experienced anything that breaks at all. _It just works_.

All my IPv6-only supporting devices like those in Apple's ecosystem seamlessly operate in IPv6-only mode, and the others that still require IPv4 addresses operate dual-stack. I fully expect that when Microsoft deploys CLAT support for Windows 11, my Windows machines will start respecting Op108 and stop taking IPv4 addresses from my pool since they won't need them anymore.

With IPv6-mostly, we can build a clear pathway to transition all the way from an IPv4-only to an IPv6-only network, with a smooth transitional phase in the middle:

![Flow diagram showing a pathway from IPv4-only networking to IPv6-only with a transitional IPv6-mostly phase in the middle](Mermaid3.png)

## Potential follow-ups
In this post, I've focused quite specifically on home networks, and on desktop/mobile devices. That was pretty necessary to avoid the post becoming even longer than it already was. There's a lot to be said in the server space for this too. Broadly, I found that applications deployed directly onto IPv6-only servers suffer largely the same pitfalls and successes as the desktop ones listed above.

The one big caveat there is that containerisation and virtualisation technologies seem to all handle this situation in quirky and interesting ways. That could (and probably will) justify a post in itself at some point in the future. Docker, Podman, WSL, QEMU - your mileage may certainly vary when trying any of the above on an IPv6-only network. If you do try it, I'd be interested to see what your conclusions and experiences are.

As part of this experimentation, I ended up deploying a full OpenBSD home router setup to create an IPv6-mostly network which implements all of the relevant RFCs (including NAT64, DNS64, PREF64 and Op108). I noticed while putting the config together that a lot of OpenBSD router config guides online focus very heavily on IPv4 networking and leave out most if not all of this kind of functionality. At some point I'll pull it all together and publish it as a guide as it might be useful to the community at large.

## Day 30+: Conclusions and recommendations for the future
Considering everything from my experience so far, I've come away with a few general recommendations:
* You should deploy IPv6 if your ISP supports it and you haven't bothered yet;
* You should deploy IPv6-_mostly_ if you're adventurous and you have access to a NAT64 gateway or you can host one yourself;
* You should deploy IPv6-_only_ if you're involved in developing software or devices that rely on networking. You'll probably learn a _lot_ from what happens, and you might be inspired to fix it. I'll buy you a beer if you do.

Speaking of learning, I learned a lot from this wild ride as always. I did end up surviving the month without re-enabling IPv4 on my LAN, but I decided that all future networks I deploy will be of the IPv6-mostly variety.

One day, I will absent-mindedly log into my router and check my DHCPv4 lease table. And there will be no entries. All my devices will behave as they should, using IPv6 and avoiding taking an IPv4 lease at all. On that day I'll be able to head over to my networking config and remove IPv4 entirely. Perhaps I'm dreaming, but having delved into transitional technologies through this project, it really does seem plausible that day might come in the next few years. That will be a good day.
