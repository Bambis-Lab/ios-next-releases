# iOS Next 1.1.1 Build 14 — Release Candidate

Status: PREPARED / NOT PUBLISHED

Source repository: Bambis-Lab/ios-next
Source branch: fix/architecture-p1-p5
Source commit: 85f25e82b9e550c1dc610678a8ed2f49771c86b9
Bundle ID: de.nicofroeba16.iosnext
Version: 1.1.1
Build: 14
Minimum iOS: 27.0
Expected artifact: IOSNext-Free-unsigned.ipa
Architecture: arm64

## Release gate

- Build with Xcode 27 and iPhoneOS 27.0.
- App-only free-sideload package; no PacketTunnel extension in the IPA.
- Verify bundle id, version, build number, executable and arm64 architecture.
- Generate and record SHA-256 and exact IPA byte size.
- Do not run motion capture. Reuse the accepted 223-frame motion baseline.
- Do not modify `source.json` until the IPA has passed the build/validation gate.

## Rollback anchor

Rollback target is the already published iOS Next 1.1.0 Build 13 release. Its GitHub release and SideStore entry must remain intact while 1.1.1 is staged and tested.
