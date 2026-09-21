# iOS Next — SideStore Distribution

This public repository contains distribution metadata and GitHub Releases for **iOS Next** only.

The private application source code is maintained separately and is not published here. No credentials, Apple signing material, provisioning profiles, tokens, private configuration, or internal development data belong in this repository.

## SideStore source

Raw source URL:

`https://raw.githubusercontent.com/nicofroeba16-cell/iOS-App-Release-/main/source.json`

SideStore deep link:

`sidestore://source?url=https%3A%2F%2Fraw.githubusercontent.com%2Fnicofroeba16-cell%2FiOS-App-Release-%2Fmain%2Fsource.json`

## App identity

- App: iOS Next
- Bundle Identifier: `de.nicofroeba16.iosnext`
- Source Identifier: `de.nicofroeba16.iosnext.source`
- Current published version: `1.0.8`
- Expected release asset name: `IOSNext.ipa`

## What's New policy

Every new SideStore version must have a canonical Markdown file at `release-notes/<version>.md` containing user-facing bullet points. Planned or unfinished features must not be listed.

The publishing helper `scripts/publish_version.py` reads that file and writes it into the new version entry's `localizedDescription`, which SideStore presents as the update / What's New description.

A new version must never be added to `source.json` before the real IPA asset, byte size, download URL and GitHub Release publication timestamp are known. SideStore treats the first compatible entry in `versions` as the latest release.

## Publishing updates

Intended release flow:

1. Build `IOSNext.ipa` from the private iOS App repository.
2. Verify that the IPA is the explicitly approved current build.
3. Verify `release-notes/<version>.md` contains the final What's New bullet points.
4. Create a GitHub Release in this repository.
5. Upload the IPA as a GitHub Release asset — never store the IPA binary in Git history.
6. Record the exact IPA byte size.
7. Read the GitHub Release `published_at` timestamp and use it as `YYYY-MM-DDTHH:MM:SSZ` in UTC.
8. Run `scripts/publish_version.py` with the final version, build version, timestamp, download URL and byte size. The helper inserts the canonical release notes into `localizedDescription` and adds the new version at the beginning of the `versions` array.
9. Validate that the newest version timestamp is not later than the GitHub Release `published_at` timestamp and is not in the future.
10. Commit the updated `source.json`.
11. SideStore discovers the new release through the stable raw source URL.

SideStore treats timed release values as UTC. The feed must use the exact GitHub Release publication time rather than a calendar date; otherwise a date-only value can become an unintended midnight-UTC countdown.

No IPA release is published until an approved artifact is available.
