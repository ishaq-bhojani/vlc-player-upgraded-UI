# Code signing policy

**Status:** Vireo's Windows releases are not code-signed yet. The project has applied to the
[SignPath Foundation](https://signpath.org) for free code signing for open-source projects.
Once the application is approved, Windows releases will carry this attribution:

> Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by
> [SignPath Foundation](https://signpath.org).

Until then, check a download against `SHA256SUMS` and the GPG signature (`.asc`) published
with each release. The public key is
[docs/redesign/reborn-update-public.asc](docs/redesign/reborn-update-public.asc).

## What is signed

Only files built from this repository by its release workflow
([.github/workflows/redesign-release.yml](.github/workflows/redesign-release.yml)): the
installer `vireo-<version>-win64.exe` and the programs and libraries in it and in the portable
`.zip`. Every build runs on GitHub Actions from a tagged commit of this repository, so each
signed file can be traced back to its source. Every release is approved by hand before it is
signed.

## Team and roles

| Role | Who |
|---|---|
| Authors (may change the source without another review) | [Ishaq Bhojani](https://github.com/ishaq-bhojani) |
| Reviewers (review every change from outside contributors, such as pull requests) | [Ishaq Bhojani](https://github.com/ishaq-bhojani) |
| Approvers (approve every signing request) | [Ishaq Bhojani](https://github.com/ishaq-bhojani) |

All team members use multi-factor authentication on GitHub and SignPath.

## Privacy

See the [privacy policy](PRIVACY.md): when Vireo connects to other computers, and how to turn
each of those connections off, including the third-party services that components of
[VLC media player](https://www.videolan.org/vlc/) can contact. The open-source components and
their licences are listed in [docs/redesign/THIRD-PARTY.md](docs/redesign/THIRD-PARTY.md).
