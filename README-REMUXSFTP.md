# RemuxSFTP

RemuxSFTP is an open-source iOS SFTP client built from
[h3nock/remux](https://github.com/h3nock/remux). Its purpose is to expose SSH
servers as writable locations in the system **Files** app through a real
Apple File Provider extension, in the spirit of Secure ShellFish.

- Direct device-to-server SFTP over Citadel/SSH. No relay, no proxy.
- Browse, download, upload, create folders, rename, move, and delete from the
  Files app.
- Server management reuses Remux's existing SSH/Keychain/trust UI.
- The File Provider stack is integrated from upstream PRs #31-#44, which were
  unmerged at the time of this fork; see `docs/remuxsftp.md` for the exact
  status and limitations.

## Build

```bash
scripts/fetch_ghosttykit.sh
xcodegen generate
open Remux.xcodeproj
```

The app and extension both need the App Group `group.dev.remux` and Keychain
Sharing (`dev.remux.shared`) in the provisioning profile. Without them the
app cannot open its shared container or read credentials from the extension.

The upstream Remux README and terminal features remain valid; this fork adds
the Files integration and its CI on top.

## Verification status

See `docs/remuxsftp.md`. The baseline has CI build and unit-test coverage;
physical-device Files-app verification is still outstanding.
