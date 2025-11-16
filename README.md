# Kanidm PPA automation

This repo holds packaging automation that builds debs from `kanidm/kanidm` and feeds them into `kanidm/kanidm_ppa`.

- Changes in how packages are defined and what they depend on live in `kanidm/kanidm`. This includes run-time dependencies.
- Changes in build-time dependencies and signing need to be addressed in this repository.
- Changes in dev instructions & user facing repo instructions need go into the book that lives in `kanidm/kanidm` .
- Changes in the public signing key need to be addressed in both `kanidm/kanidm_ppa` & this repo.

For instructions how to use this repo for manual builds, see the book at:
<https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html>

## Release process

To cut a new release after upstream does, perform the following steps:

1. Modify `.github/workflows/create-apt-repo.yml`:
   - Update the matrix category map to bump versions, prefer a tag `ref`.
     If a new `minor` version has been released,
     remove the oldest one so only two are always present.
   - Check the matrix os map for any distros where support
     has ended or a new release should already be added.
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
   - Modify the matrix os map for any distros where support
     has ended and drop them. Add any replacements and modify
     the `support` type as needed.`
   - Update the PPA csv data under the `Create Aptly repo` step.

2. Update the testing harness:
   - Modify `testing/lib/targets.sh` to remove old distro cloud image
     references and add new ones.
   - Modify `testing/scripts/run-all.sh` to update the test sets.
     Check the lines starting with `targets=`. There are three sets
     to potentially modify, the base LTS set, old LTS set and the
     interim releases set.
