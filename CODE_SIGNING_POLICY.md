# Code signing policy

Lumigram's Windows releases are built from this repository by the
[Release workflow](.github/workflows/release.yml) on GitHub-hosted runners, so
every published installer can be traced to the commit it was built from.

Free code signing provided by [SignPath.io](https://about.signpath.io),
certificate by [SignPath Foundation](https://signpath.org).

> Lumigram has applied to SignPath Foundation. Until the application is
> approved, releases are unsigned, and the release notes say so.

## What gets signed

- `Lumigram.exe`, the app itself.
- `Lumigram-Setup-x64-<version>-<label>.exe`, the installer.

Only files built by the Release workflow from this repository are signed.
Upstream libraries that come unsigned stay unsigned.

## Team roles

| Role | Who |
| --- | --- |
| Committers and reviewers | [Members of the repository](https://github.com/KakunArtem/Lumigram/graphs/contributors) with write access: [KakunArtem](https://github.com/KakunArtem) |
| Approvers | Repository owner: [KakunArtem](https://github.com/KakunArtem) |

Every change from anyone without write access, including the upstream
Telegram Desktop changes merged through `sync/<version>` pull requests, is
reviewed by a reviewer before it reaches `dev`. Every signing request is
approved by hand by an approver. All team members use multi-factor
authentication for GitHub and SignPath.

## Privacy

This program will not transfer any information to other networked systems
unless specifically requested by the user or the person installing or
operating it.

Lumigram connects to Telegram's servers only to do what the user asks of a
Telegram app: sign in, send and receive messages, calls and files. Release
builds have automatic updates and crash reports turned off, so Lumigram sends
nothing anywhere else. See [Telegram's privacy policy](https://telegram.org/privacy)
for how Telegram handles account data.
