# Kanidm PPA automation

This repo holds packaging automation that builds debs from `kanidm/kanidm` and feeds them into `kanidm/kanidm_ppa`.

- Changes in how packages are defined and what they depend on live in `kanidm/kanidm`. This includes run-time dependencies.
- Changes in build-time dependencies and signing need to be addressed in this repository.
- Changes in dev instrctions & user facing repo instructions need to into the book that lives in `kanidm/kanidm` .
- Changes in the public signing key need to be addressed in both `kanidm/kanidm_ppa` & this repo..

For instructions how to use this repo for manual builds, see the book at:
https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html
