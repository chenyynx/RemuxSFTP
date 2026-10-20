# RemuxSFTP: SFTP locations in the iOS Files app

RemuxSFTP is a fork of [h3nock/remux](https://github.com/h3nock/remux) that
adds a writable Apple File Provider extension backed by a direct
Citadel/SSH SFTP connection. It does not use a relay or a server-side proxy.

Status on 2026-10-20: integration baseline. The code is merged and building
in CI; it has not been run against a physical iOS device yet. Treat every
Files-app behavior below as code-level until a device run is recorded.

## What the extension implements

`RemuxFileProvider` is an `NSFileProviderReplicatedExtension`:

| Files-app action | Entry point |
| --- | --- |
| Browse a directory | `enumerator(for:)` -> `FileProviderEnumeratorCore` |
| Download / open a file | `fetchContents(for:version:request:)` |
| Upload a new file | `createItem(basedOn:fields:contents:options:request:)` |
| Create a folder | `createItem` with `UTType.folder` |
| Rename / move | `modifyItem(_:baseVersion:changedFields:contents:options:request:)` |
| Replace contents | `modifyItem` with `.contents` |
| Delete | `deleteItem(identifier:baseVersion:options:request:)` |

The extension exposes one Files location per saved SSH server. A location is
created when the server has a stored credential and a trusted host key, and
it is removed when either condition stops holding
(`FileProviderDomainReconciler`).

The remote root is the SSH user's canonical home directory (`realpath(".")`).
Every request re-resolves the canonical path and rejects paths or symlink
targets that escape that root (`FileProviderPathValidation`,
`FileProviderSafeLinkResolver`).

Uploads are written to a temporary sibling and renamed into place
(`FileProviderMutationCore`). A failed upload removes its temporary file.
Mutations validate the base version and return the standard File Provider
collision/conflict errors. Non-empty directories are never deleted
recursively; the system deletes their children first.

## Storage and credentials

The app and extension share two capabilities:

- App Group `group.dev.remux` for profiles, trusted host keys, and snapshot
  generations.
- Keychain access group `$(AppIdentifierPrefix)dev.remux.shared` for SSH
  credentials.

On first launch after upgrading, `FileProviderSharedStorageMigrator` copies
the legacy app-only profiles and credentials into the shared container and
verifies the copy before writing its one-time marker. A failure aborts the
migration and surfaces as a launch error rather than silently exposing an
empty or stale location.

## Security properties

- Host keys must already be trusted by the app; the reconciler will not
  publish an untrusted server.
- Credentials are read from the shared Keychain per operation; they are not
  written to the app group container or to logs.
- Remote paths are validated before use: no `..`, no NUL, no absolute
  relative paths, and no symlink target outside the canonical home.
- Symlinks are listed only when their canonical target stays inside the home;
  mutating through a symlink is rejected.
- The extension links no third-party networking besides Citadel/NIO.

## Known limits

- Every trusted server with a credential becomes a Files location. There is
  no per-server enable/disable switch yet.
- Adding a server verifies SSH by running `exit 0`, so an SFTP-only account
  with no exec channel is rejected at setup time.
- The remote root is fixed to the login home; it is not configurable per
  server.
- Listing is not paginated; a directory is read in full.
- Each active enumerator polls its directory every five seconds, and each
  operation opens a short-lived SFTP session. This is correct but not tuned
  for large trees or metered connections.
- The in-app UI is still Remux's terminal-first UI. Files integration happens
  automatically; there is no in-app file browser.
- App Group and Keychain Sharing must be enabled in the provisioning profile
  used to sign both targets. Simulator builds do not prove this.

## Build and test

Prerequisites: Xcode with the iOS 18 SDK, XcodeGen 2.46.0, and the pinned
GhosttyKit release used by the app target.

```bash
scripts/fetch_ghosttykit.sh
xcodegen generate
xcodebuild build \
  -project Remux.xcodeproj \
  -scheme RemuxFileProvider \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
xcodebuild test \
  -project Remux.xcodeproj \
  -scheme Remux \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:RemuxTests
```

`.github/workflows/fileprovider-ci.yml` runs the extension build first, then
the app unit tests including the File Provider suites.

## Upstream status

The writable File Provider stack comes from upstream pull requests #31-#44
(`codex/file-provider-review/*`). All of those PRs were still open when this
baseline was created. Remux's `main` had no File Provider code. This fork
merges the stack, adapts it to the newer `SessionTarget`/Tailscale SSH code,
and adds CI; it does not claim that upstream has shipped these features.
