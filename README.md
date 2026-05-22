# Kanidm PPA automation

This repo holds packaging automation that builds debs from `kanidm/kanidm` and feeds them into `kanidm/kanidm_ppa`.

- Changes in how packages are defined and what they depend on live in `kanidm/kanidm`. This includes run-time dependencies.
- Changes in build-time dependencies and signing need to be addressed in this repository.
- Changes in dev instructions & user facing repo instructions need go into the book that lives in `kanidm/kanidm` .
- Changes in the public signing key need to be addressed in both `kanidm/kanidm_ppa` & this repo.

For instructions how to use this repo for manual builds, see the book at:
<https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html>

## Distribution support policy

For the user facing (less detailed) guidance, see: <https://kanidm.github.io/kanidm_ppa/>.

### Kanidm versions

The intent is to always have available the latest `patch` releases of the two latest `minor`
releases. In practice this means that if `1.10.3` is the latest release,
we carry `1.10.3` & `1.9.4`, but not `1.8.6`. This is slightly more lenient than the upstream
Kanidm support policy which defines a time-limit for the previous `minor` release. However,
temporarily we may drop a known-vulnerable version from distribution if a patched version is
not available due to the stricter support policy.

To avoid surprises, stay with the latest Kanidm release. The old one is there to give you more
runway to upgrade and an opportunity to downgrade if facing issues, not to stay on old releases.

### Kanidm components

We provide the following packages:

- `kanidm`: The cli client.
- `kanidm-unixd`: The unix integration daemon.
- `libpam-kanidm`: Support library for integration of `kanidm-unixd` with PAM.
- `libnss-kanidm`: Support library for integration of `kanidm-unixd` with NSS.
- `kanidmd`: The main Kanidm server daemon.

While `kanidmd` is provided as a package, it is recommended to instead use a container based deployment.
For details see: <https://kanidm.github.io/kanidm/stable/preparing_for_your_deployment.html>

### Distribution versions

We package for Debian & Ubuntu. Packages for one or the other are likely to also be compatible with
their derivatives but this is not supported or tested for.

The overarching goal is to have enough coverage to support those who upgrade their
OS "within a reasonable timeframe" while keeping our build matrix size stable and small enough
so that release builds do not take more than an hour on average and that the built repo stays
under the artifact size limits.

For both the intent is to support their latest two stable releases, and one interim release if
available. We do not align to distribution release or end of life dates, but whenever a new
release of Kanidm is cut, the support matrix is updated to reflect this policy. We do not provide
a crossover period where both the latest stable and previous oldest stable are available at the
same time, as you always have an oldstable available. With interim releases you're already living
dangerously and expected to move to the next rapidly. The new interim release may work with the
cronological previous release, but there are no guarantees.

#### Debian

- `stable` & `oldstable` are supported.
- We do not support `unstable`, `testing` or `lts`.
- At time of writing this means `trixie` & `bookworm` are supported while `bullseye` is not.
- For definitions, see: <https://www.debian.org/releases>

#### Ubuntu

- The two latest LTS releases, and the latest interim release are supported.
- The Ubuntu release schedule always has three LTS releases supported, but we do not include the third.
- At time of writing this means `resolute`, `noble` and `questing` are supported, while `jammy` is not.
- For definitions, see: <https://releases.ubuntu.com/>

## Release process

To cut a new release after upstream does, perform the following steps:

1. Modify `.github/workflows/create-apt-repo.yml`:
   - Update the matrix category map to bump versions, prefer a tag `ref`.
     If a new `minor` version has been released,
     remove the oldest one so only two are always present.
   - Check the matrix os map for any distros where a new stable or interim
     may have been released and perform changes as per the distro support policy above.
     See [Modifying distro support](#modifying-distro-support)
     for necessary steps.

2. Create a PR:
   - Commit your changes into a new branch and push to your fork.
     On GitHub, open a new PR in `Draft` state against the main repo.
   - Get a project contributor to check your PR and run GitHub Actions
     for your PR. In the meanwhile you can run them in your fork by either
     merging to the `main` branch or dispatching the workflow manually.
   - The workflow fanout is large and some steps can fail due to network
     issues. GitHub Actions allows retrying failing steps from the workflow
     overview which is significantly faster than a full re-run. This may also
     happen with the final build after merge and needs watching out for.

3. Run conformance testing:
   - Once GitHub Actions has successfully run through the workflow,
     open the summary of the workflow run and at the very bottom
     in the artifacts section you will find a download link for
     `kanidm_ppa_snapshot.zip`. Download the archive and place it into your
     working copy as `testing/kanidm_ppa_snapshot.zip`
   - Follow the testing guidance to run through all permutations:
     [Testing procedure](/testing/README.md#testing-procedure). Using
     the "easy way" guidance with the help of [Mise](https://mise.jdx.dev/) is highly encouraged
     for the sake of consistency, it's easy to otherwise miss a portion of testing.
     Please note that you need to repeat the test suite on both
     x86_64 and arm64. Using real non-emulated hardware is highly encouraged
     for performance reasons. A native hardware run can easily
     take 40 minutes, but emulated you'll be at it for hours.

4. Troubleshoot any issues identified during testing, or declare victory:
   - If any trouble was found, update your PR with details. Issues are usually
     either across all tests of a version, or isolated to a newer generation
     of distros.
   - Once all tests pass, mark the PR ready for review.

5. Once published, install the updated packages on a real system.
   - You still have a bit of time to quickly fix your mistake if something
     wasn't caught in testing.
   - Probably a good idea to be vocal about any late found issues in the
   Kanidm community channel, see: [Kanidm Community](https://kanidm.com/community/).

## Modifying distro support

1. In `.github/workflows/create-apt-repo.yml`:
   - Modify the matrix os map for any new distro versions and subsequent drops. In
     practice this means any of:
     - Swap in a new `stable`, drop `oldstable` and demote previous `stable` to `oldstable`.
     - Switch out an `interim` for the latest available interim release.
   - Update the PPA csv data under the `Create Aptly repo` step to match.

2. Update the testing harness:
   - Modify `testing/lib/targets.sh` to remove old distro cloud image
     references and add new ones.
   - Modify `testing/scripts/run-all.sh` to update the test sets.
     Check the lines starting with `targets=`. There are three sets
     to potentially modify for stable, oldstable & interim. Order matters.

## Other maintenance tasks

We rely on a handful of external "non-official" Github Actions for the release CI.
They may occasionally require updates, but due to the general state of supply chain security
we want to be deliberate about updates. To facilitate this the repo contains a still overly
simple [updatecli](https://www.updatecli.io/) config which allows locally bumping versions
and tying them to current latest release hashes. Any bumping should be accompanied by a cursory
review of what's changed, but that may at times be quite hard due to the use of js minification.
Do your best.

Example dependency update invocation:

```shell
GITHUB_TOKEN="$(gh auth token)" updatecli pipeline apply
```

- The changes will be done in your currently checked out copy which allows local diffing & manual commit.
- Ignore the warnings caused by the matrix sharding, ideally these would somehow be skipped or silenced
since it's a false positive due to our use of vanilla images.
