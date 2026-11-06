+++
title = 'I deleted all my SSH keys'
date = 2026-11-04T11:00:00Z
draft = false
summary = "Migrating to hardware-resident SSH keys for everything."
tags = ['security']
+++

I've been using `ed25519-sk` keys with YubiKeys since practically the moment they were available. But because of some specific use-cases (and because, frankly, YubiKeys are expensive) I've had a few traditional on-disk keys hanging around for a while just waiting for me to finally decide to get rid of them.

This post documents how I'm using various secure enclaves (YubiKey, TPM, Apple Secure Enclave) to hold/encrypt SSH key material and achieve the goal of not having any unprotected key material living on-disk.

## First -- Isn't using a passphrase enough?
Probably. I don't intend to imply that this post is the _only_ way that anyone should be doing SSH keys. Using a passphrase will encrypt the key with bcrypt & AES which keeps it protected even if the on-disk keyfile leaks somehow.

And with a functioning ssh-agent, the passphrase should only need to be entered once per session, with the decrypted key material being held in RAM after that point.

So yes, the 'traditional' method is probably fine for most threat models. But I'm still keen to move to hardware-backed keys anyway, mostly for the satisfaction.

## About hardware-resident keys
When I say 'hardware-resident' keys, I mean keys that use a secure enclave or purpose-built hardware like [YubiKeys](https://www.yubico.com/) to store or protect the key material.

The theoretical benefit here is that the hardware used to _generate_ the SSH key is needed in order to _use_ the key. There's no mechanism that allows leaking or exfiltrating keys that generated using this method. Any material that _does_ exist on-disk is useless without the hardware.

## Goals
So I want to:
* Switch to using hardware-resident keys entirely
* Do so as natively as possible, avoiding additional software where I can
* Test these in various real-world scenarios, such as running within an LXC or noninteractively mounting an SSHFS server

## Hardware
I'm going to try three different hardware methods for achieving this, which I think will cover all of my needs:
* Method 1: YubiKey
* Method 2: TPM
* Method 3: Apple Secure Enclave

## Method 1: YubiKey
With a YubiKey (5 and newer), SSH keys can be directly enrolled into the device using `ed25519-sk` (where the `-sk` stands for "Security Key"). This doesn't require any additional software beyond OpenSSH itself.

To store a new SSH key on a YubiKey, insert it and run:
```sh
ssh-keygen -t ed25519-sk -O resident -O application="ssh:yournamehere" -f ~/.ssh/id_ed25519-sk
```

The `application` tag set in the command is arbitrary and can be set to whatever memorable string you prefer to differentiate between multiple SSH keys if you want to create multiple keys on the same YubiKey.

If you have `ykman` installed, you can now inspect the list of credentials enrolled in the device:
```text
$ ykman fido credentials list
Enter your PIN: 
Credential ID  RP ID             Username  Display name
0f41fb61...    ssh:yournamehere  openssh   openssh
```

If `ykman` complains that you haven't set a FIDO PIN on the YubiKey yet, you can do this with `ykman fido access change-pin`.

Note that you don't actually need `ykman` to enrol or use SSH keys with a YubiKey but it does make managing the device more convenient.

Once the key has been created, you can retrieve the public key from disk:
```text
$ cat ~/.ssh/id_ed25519-sk.pub 
sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA9B+2GGCkQvBzpa4WobQhfC9YU5Su3pKXBmVLSXEqfRAAAAEHNzaDp5b3VybmFtZWhlcmU= alice@hostname
```

This key can be used like any other SSH public key -- added to `authorized_keys` on a host, copied with `ssh-copy-id`, or pasted into services that depend on SSH like Git forges.

You will also find a `~/.ssh/id_ed25519-sk` file on disk (without the `.pub` extension). Note that although this _looks_ like a private key, it doesn't actually contain the key material. This is just a handle to find the relevant key on the hardware device.

To configure the key for authentication, it can be enrolled with `ssh-add` like a regular key, or specified directly in `~/.ssh/config`:
```text
Host blog.infected.systems
    IdentityFile ~/.ssh/id_ed25519-sk
```

From here, you can now SSH into the destination host as with a regular key. SSH will ask you to tap the YubiKey to confirm presence when the SSH command runs.

### Unattended YubiKey usage
When using an `ed25519-sk` key created with the default settings as above, you will be asked to confirm your presence whenever the key is used by physically touching the YubiKey.

It's probably a good idea to keep this default, but if you have a specific use-case that requires unattended key usage, you can generate a `no-touch-required` key as follows:

```sh
ssh-keygen -t ed25519-sk -O resident -O no-touch-required -O application="ssh:nameyourkey" -f ~/.ssh/id_ed25519-sk
```

When using a `no-touch-required` key, although it isn't possible for a malicious actor to exfiltrate the key even with root access to the host the YubiKey is plugged into, a malicious actor with access could use the key without requiring any presence detection or human interaction. So do make sure this is actually suitable for your risk appetite before doing it.

To use a `no-touch-required` key for unattended authentication to remote servers, you need to prepend the entry in the `authorized_keys` file on the destination host with `no-touch-required`, otherwise OpenSSH's default security settings will reject the key.

For example:
```text
$ cat ~/.ssh/authorized_keys 
no-touch-required sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIA9B+2GGCkQvBzpa4WobQhfC9YU5Su3pKXBmVLSXEqfRAAAAEHNzaDp5b3VybmFtZWhlcmU= alice@hostname
```

## Method 2: TPM
YubiKeys are nice, though fairly expensive. It would be useful if we could use the TPM we already have on our host to protect key material instead. Well, it turns out we can!

Unfortunately this does require additional software, but it's a fairly minimal Golang package -- [ssh-tpm-agent](https://github.com/Foxboron/ssh-tpm-agent). It can be installed with Go directly from GitHub, but is natively packaged by Ubuntu and [I'm working on packaging it for Fedora](https://bugzilla.redhat.com/show_bug.cgi?id=2565411).

To create a TPM-backed SSH key with a PIN, run:
```sh
ssh-tpm-keygen -N "your-pin"
```

The process will ask you where to store the key. From here, once again we have a keypair with a `.pub` file that we can use in `authorized_keys` or copy however we wish.

To use the TPM-backed key we need to use the TPM-aware SSH agent provided by the `ssh-tpm-agent` package. If you installed the native Golang package rather than something vendored by your distribution, you can enable the systemd socket unit for the agent as follows:
```sh
ssh-tpm-agent --install-user-units && systemctl --user enable --now ssh-tpm-agent.socket
```

To ensure the socket for the agent can be discovered by SSH processes run within your shell session, add the following to your `.bashrc` or the equivalent for your shell:
```sh
export SSH_AUTH_SOCK="$(ssh-tpm-agent --print-socket)"
```

Again, we can now use this key to authenticate to servers as if it were any other traditional on-disk key.

### Unattended TPM usage
If you want this key to be available unattended, or to services that don't use a full shell such as [systemd mount units](/posts/2025-10-14-the-five-megabyte-nas/), you can create a new key without a PIN (pass `-N ""` to the `ssh-tpm-keygen` command) and specify the socket path in `~/.ssh/config` instead of relying on `SSH_AUTH_SOCK` (although this relies on the socket address being predictable -- i.e. your UID being stable):
```text
Host blog.infected.systems
    IdentityAgent /run/user/1000/ssh-tpm-agent.sock
    IdentityFile ~/.ssh/id_ecdsa
```

Note that `ssh-tpm-agent` does not account for the values in the TPM Platform Configuration Registers (PCRs) which record the state of the booted system -- firmware versions etc, so changes of hardware/firmware/OS will not cause the system to refuse to unseal the key (unlike, say, something like BitLocker). So ensure that using a PIN-free key is appropriate for your risk model before doing so.

### A caveat regarding TPM keys
You will notice though that the private keyfile held on disk uses a `.tpm` extension this time. This is where an important caveat of the TPM method comes in -- Unlike the YubiKey approach, the private key material _is_ actually being stored on disk here. This is because TPM devices do not natively support enrolling SSH keys. So what is happening is that the private key material is being stored on disk in encrypted form, and the TPM is being used to decrypt it.

This is still a device-bound credential as the key cannot be used without the TPM device even if the keyfile is leaked or exfiltrated but it is a relevant distinction compared to device-_resident_ credentials such as `-sk` keys.

## Method 3: Apple Secure Enclave
As of macOS Sequoia, the Smart Card Auth system within macOS is able to natively handle SSH keys as identities.

We can generate one as follows:
```sh
sc_auth create-ctk-identity -l "ssh-labelyourkey" -k p-256-ne -t bio
```

The options above:
* `-l` labels our key. Choose a unique and useful name here as we'll need this to find the right key handle file on disk later.
* `-k p-256-ne` creates a non exportable (`-ne`) key. This is important to ensure we're actually creating a key that will stay resident in the enclave.
* `-t bio` requires TouchID to use the key.

Then we can list the key:
```text
% sc_auth list-ctk-identities

Key Type Public Key Hash                          Prot Label            Common Name      Email Address Valid To          Valid 
p-256-ne B15235464F87EC7C8DEE89BFA06399FFD6678E99 bio  ssh-labelyourkey ssh-labelyourkey               04/11/2027, 09:29 YES
```

To export a handle to disk that allows OpenSSH to use the key from the secure enclave, you can do:
```sh
(cd ~/.ssh && ssh-keygen -w /usr/lib/ssh-keychain.dylib -K -N "")
```

When prompted for a pin during export, you can leave it blank as it isn't used here. A public key and private key handle file will be created on-disk in the `~/.ssh` directory.

Note that the command above will export a key handle for _all of the SSH keys_ you have enrolled in the Secure Enclave (you can create many if desired by repeating the process above). I wasn't able to find a way to export individual key handles [despite Apple's docs suggesting that you should be able to with KEYCHAIN_CERTIFICATES](https://keith.github.io/xcode-man-pages/ssh-keychain.8.html). Your best bet will be to use a clear label using the `-l` flag when creating the key so you can easily find the handle for it after it has been exported to disk.

Once we have our pubkey and handle file, we can process these as we normally would -- copying the public key to an `authorized_keys` file on a remote host or adding it to whatever services we prefer.

To use SSH keys from the Secure Enclave, we need to set `SSH_SK_PROVIDER` in our shell. We can add this to `~/.zshrc`:
```sh
export SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib
```

After a restart of the shell, the key will work like any other -- though you may need to specify it directly as in my case it wasn't being autodiscovered by macOS's SSH agent:
```text
Host blog.infected.systems
    IdentityFile ~/.ssh/id_ecdsa_sk_rk_ssh-labelyourkey
```

### Running a Mac in 'clamshell mode'
If you run your Mac in what Apple calls 'clamshell mode' (i.e. a laptop with the lid shut), then the initial `create-ctk-identity` command will fail with an error like this:
```text
Error: Error Domain=com.apple.LocalAuthentication Code=-4 "Touch ID is not available in closed clamshell mode." UserInfo={BiometryType=1, Subcode=10, NSDebugDescription=Touch ID is not available in closed clamshell mode., NSLocalizedDescription=Authentication canceled.}
```

Unfortunately it seems that keys created with `-t bio` do actually require full TouchID in order to generate or use -- unlike other operations such as unlocking the Safari Keychain or using Apple Pay which fall back to a user password when in clamshell mode.

There is an option to use `-t none` to create a key without presence confirmation enabled at all. This carries the same risk as I discussed in the section about using YubiKeys unattended so you'll have to decide whether it works for your risk model.

If, like me, you use the machine in clamshell mode basically all the time there are some alternative options that still retain presence detection though:
* You could buy one of Apple's [expensive bluetooth keyboards with Touch ID](https://www.apple.com/uk/shop/product/mxck3b/a/magic-keyboard-with-touch-id-for-mac-models-with-apple-silicon-usb-c-british-english).
* Or, the [YubiKey 5C Nano](https://www.yubico.com/gb/product/yubikey-5c-nano/) is tiny and can sit almost flush in the side of a closed MacBook and can be used with Method 1 including presence detection.

## Final note
With a mix of these three approaches, I've finally been able to deprecate on-disk keys from all my setups.

Hopefully some of the info in this post is helpful to people! It's nothing that can't already be found online but I've gathered it into one place mostly for my own convenience.

The main gotcha to be aware of with hardware-resident keys is that they're, well, hardware resident. Hardware malfunction/loss/change can render keys unusable. So it's probably better to make sure you at least have multiple keys. Remember, `authorized_keys` can take as many keys as you care to put in it so redundancy is the best move here I think.
