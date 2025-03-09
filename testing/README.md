# QEMU based integration testing

> This place is not a place of honor... no highly esteemed deed is commemorated here... nothing valued is here.
What is here was dangerous and repulsive to us. This message is a warning about danger. 

Testing other architectures is even more Fun than packaging for them. The scripts here make it plausible, if not exactly great.

1. `cd` to the root of the `testing/` dir.
1. Download a GHA repo snapshot artifact zip and place it in the current directory as `kanidm_ppa_snapshot.zip`
1. Run `scripts/install-deps.sh` to install system level dependencies such as qemu. It assumes Debian, so you may need to substitute as necessary.
1. Make sure your user can run qemu. Generally this means being added to the `kvm` group.
1. Run `IDM_URI=https://idm.example.com scripts/run-all.sh`, you may want to override other bits of env, see the bottom of this README.
   - At first your snapshot is unpacked and a mirror is launched with the contents listening on localhost.
   - You can view what's going on in the console of the qemu VM with `nc localhost 4321`, this is only necessary if something goes horribly wrong.
   - You can poke at the qemu console itself with `socat -,echo=0,icanon=0 unix-connect:qemu-monitor.socket`
1. Once the VM is up and reachable, integration starts. Once it's following the kanidm-unixd & sshd logs you're ready to test.
   If anything goes wrong, execution will pause instead with a warning to allow investigation.
1. Testing time.
   - A good basic test is to run in another terminal:
   ```shell
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    localhost -p 2222 \
    "uname -a && cat /etc/os-release && kanidm login -D anonymous && kanidm self whoami"
   ```
   - Or if that doesn't work, troubleshoot via the cloud-init injected root key:
   ```shell
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i ssh_ed25519 root@localhost -p 2222
   ```
1. Once  happy with the permutation, hit `^C` in the original terminal to terminate the permutation. Hit `Enter` to continue to the next one.
1. Iterate until your willpower has crumbled or you reach the end of the target list.

### Known issues
- aarch64 is super slow cross-arch, so we disable cross-arch by default. Instead, run the same testing natively on an aarch64 platform and it'll work ok.
- We throw 4 cores for the cpu so that mounting the rootfs is fast enough to not time out on ubuntu. Yes, that's a crazy problem to have.
- If you insist in running aarch64 cross-arch, beware that systemd will throw weird hissyfits. The arguments try to work around it, but it's not foolproof.
- We expand every disk image a bit because some default image sizes only leave ~200MiB of free space which isn't enough for our deb sizes to go through dpkg copy logic.
  This makes GPT unhappy, but that seems to be ok.

### Config tweaks
You can set various environment variables to change testing behavior, either to suit your environment, or to test different things.

#### Testing different things
- `CATEGORY` - Which mirror category to install, `stable` (default) or `nightly`.
- `KANIDM_VERSION` - Version prefix to install from the category. `1.4` would install the latest available 1.4, say 1.4.6. The default is latest.
- `USE_LIVE` - Use the live Kanidm PPA mirror instead of a local snapshot. Default is `false`.

#### Settings for your environment
- `IDM_URI` - Change which live kanidm server is used. Your user is expected to have SSH & posix enabled on this server.
- `IDM_GROUP` - A posix enabled group on the above server to gate unixd authentication.

#### Port settings
All ports are bound only on localhost, so should normally not interfere with other activity.

- `MIRROR_PORT` - 31625 - Port to use for the snapshot mirror httpd
- `SSH_PORT`    - 2222  - Port for the VM SSHD to listen on
- `TELNET_PORT` - 4321  - Port for the VM console to listen on
