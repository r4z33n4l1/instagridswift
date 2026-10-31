# Recovery index: r4z33n4l1/instagridswift

Saved on October 31, 2026. The `manifest.json` file lists the exact commit hashes,
recovery tags, staged/working snapshots, deleted paths, and excluded files.

## Retrieve a snapshot

Clone this repository and fetch its tags. Choose a `local-backup/2026-10-31/...`
tag from the manifest. To inspect its files in a separate folder:

```sh
git worktree add ../recovered-project TAG_FROM_MANIFEST
```

Snapshot commits contain the selected source files. Credentials, captured sessions,
dependencies, generated state, unavailable cloud placeholders, and oversized files
may have been excluded. Read the exclusions before replacing a working folder.
Source branches and production branches were not merged during this backup.

## Recover original local history

Original-history tags retain their original commit identities. Where present,
`history.bundle` preserves additional safe local branches and stashes.
Its checksum and any prerequisite GitHub repository are in the manifest.
For a thin bundle, first clone the prerequisite repository with its full history.
Then run `git bundle verify /path/to/history.bundle`, followed by:

```sh
git fetch /path/to/history.bundle 'refs/audit/local/*:refs/recovered/*'
```

The recovered refs preserve original branch/stash commits. Keep them separate from
main until the work is reviewed. Snapshot code was not build-tested or merged.
