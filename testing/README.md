# QEMU based integration testing

> This place is not a place of honor... no highly esteemed deed is commemorated here... nothing valued is here.
What is here was dangerous and repulsive to us. This message is a warning about danger. 

Testing other architectures is even more Fun than packaging for them. The scripts here make it plausible, if not exactly great.

1. `cd` to the root of the `testing/` dir.
1. Modify `unixd.toml` & `kanidm.toml` to match your live deployed Kanidm environment that has a user with posix & ssh keys set up.
1. Download and unpack GHA deb artifacts into `debs/{stable,nightly}`. The default sequence only tests stable, so may not want to bother with nightly.
   - A correct looking path would be: `debs/stable/stable-debian-12-aarch64-unknown-linux-gnu/kanidm-unixd_1.3.3-202410071359+ae1df93_arm64.deb`
1. Run `scripts/run-all.sh`, you may want to modify the port allocations or target sequence in it first.
1. QEMU VMs cross-architecture are slow, very very slow.
   - You can view what's going on in the console with `nc localhost 4321`
   - You can poke at the qemu console itself with `sudo socat -,echo=0,icanon=0 unix-connect:qemu-monitor.socket`
1. Once the VM is up and reachable, integration starts. Cross-arch this is also very slow. Once it's following the sshd log you're ready to test.
1. Testing time.
   - A good basic test is to run in another terminal:
   ```shell
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost -p 2222 "uname -a && cat /etc/os-release"
   ```
   - Or if that doesn't work, troubleshoot via the cloud-init injected root key:
   ```shell
   sudo -E ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ssh_ed25519 root@localhost -p 2222
   ```
1. Once  happy with the permutation, hit `^C` in the original terminal to terminate the permutation. Hit `Enter` to continue to the next one.
1. Iterate until your willpower has crumbled or you reach the end of the target list.

### Known issues
- aarch64 is super slow. If you're a QEMU wizard, try optimizing `scripts/launch-one.sh`
- We throw 4 cores for the cpu so that mounting the rootfs is fast enough to not time out on ubuntu. Yes, that's a crazy problem to have.
- Newer versions of systemd on the target image are susceptible to odd crashes. Anything tried to make them better instead made everything else so much worse.
- We expand every disk image a bit because some default image sizes only leave ~200MiB of free space which isn't enough for our deb sizes to go through dpkg copy logic. This makes GPT unhappy, but that seems to be ok.
- Too many things require sudo. You could probably somehow run qemu without it but meh.
