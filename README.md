# Kanidm PPA automation

This repo holds packaging automation that builds debs from `kanidm/kanidm` and feeds them into `kanidm/kanidm_ppa`.

- Changes in how packages are defined and what they depend on live in `kanidm/kanidm`. This includes run-time dependencies.
- Changes in build-time dependencies and signing need to be addressed in this repository.
- Changes in user facing repo instructions and the public signing key need to be addressed in `kanidm/kanidm_ppa`.

For instructions how to use this repo for manual builds, see: https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html
