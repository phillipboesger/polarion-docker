# Project Log

Most recent entries appear first. Older entries may be moved to PROJECT_LOG_ARCHIVE.md.

---

<!-- entries below -->

## 2026-04-19 - Restored /repo-local admin/admin by switching to file auth

**Branch**: main
**What was done**: Investigated failing `/repo-local` Basic Auth and found the running `ghcr.io/...:latest` container still used DBD-only auth for `/repo-local`, with Apache reporting missing relation `polarion_internal.svnauthn` and repeated `AH01617 Password Mismatch` for `admin`. Updated local Apache generation to use `AuthUserFile` + `AuthBasicProvider file` for `/repo-local` and applied the same configuration as a hotfix inside the running `polarion-dev` container, then reloaded Apache.
**Changed files**:

- entrypoint.d/05-configure-apache.sh - switched `/repo-local` to file-based auth (`AuthUserFile /srv/polarion/svn/passwd`, `AuthBasicProvider file`) and enabled `authn_file`
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- In the current `ghcr.io/phillipboesger/polarion-docker:latest`, Apache DBD for `/repo-local` can fail with `AH00632` because `polarion_internal.svnauthn` is not present; this blocks admin/admin even when the endpoint is reachable
- `/repo-local` as dedicated local endpoint should prefer file-based auth when deterministic `admin/admin` access is required
  **Open / Next steps**:
- Rebuild/restart from repository sources (or publish new image) so this fix is persisted and not only hotfixed in the current running container

---

## 2026-04-19 - Restored host HTTP default to port 80

**Branch**: main
**What was done**: Switched runtime and VS Code task defaults back from `8080` to `80` so Polarion is reachable again at `http://localhost/polarion/` without a port suffix. Restarted the container with default settings and verified host mapping plus endpoint reachability.
**Changed files**:

- scripts/polarion-runtime-lib.sh - changed default `POLARION_HTTP_PORT` from `8080` to `80`
- .vscode/tasks.json - changed default `POLARION_HTTP_PORT` from `8080` to `80`
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- If `.vscode/tasks.json` pins `POLARION_HTTP_PORT=8080`, task-based starts override script defaults and keep publishing only `8080:80`
- After reverting defaults to `80`, `http://localhost/polarion/` and `http://127.0.0.1/polarion/` both return `200`; `:8080` is unavailable unless explicitly configured
  **Open / Next steps**:
- If a parallel setup still needs `8080`, set `POLARION_HTTP_PORT=8080` only for that invocation instead of changing repository defaults

---

## 2026-04-19 - Fixed repo-local auth mismatch by switching to DBD auth

**Branch**: main
**What was done**: Reproduced the issue in a live browser login flow and confirmed repeated Apache `AH01617 Password Mismatch` for `/repo-local/.polarion/.../admin/page.xml` while using file-only auth on `repo-local`. Switched `repo-local` to DBD auth with Polarion default `svnauthn` query, rebuilt and restarted, then re-ran login and log checks.
**Changed files**:

- entrypoint.d/05-configure-apache.sh - changed `polarionSVN-local.conf` from `AuthBasicProvider file` to `AuthBasicProvider dbd` and added `AuthDBDUserPWQuery` using `polarion_internal.svnauthn`
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- `repo-local` with file-only auth can still fail for logged-in UI users even if `admin/admin` works via curl, because Polarion SVN calls use user credentials that must match auth backend semantics
- Matching `/repo` default auth model (DBD + svnauthn) on `/repo-local` removes the mismatch loop while preserving untouched default `/repo`
  **Open / Next steps**:
- Validate with user-driven navigation that no new `ISVNAuthentication provider did not provide credentials` entries are produced in the next session

---

## 2026-04-19 - Reverted /repo customization and introduced dedicated /repo-local endpoint

**Branch**: main
**What was done**: Reworked startup/auth handling to match Polarion defaults for `/repo` and removed all custom rewrites of `polarionSVN.conf` for that endpoint. Added a separate Apache config for `/repo-local` with file-based auth (`admin/admin`) and pointed `polarion.properties` to `http://localhost/repo-local` for local runtime usage.
**Changed files**:

- entrypoint.d/99-start-polarion.sh - removed `/repo` auth patching logic and now only sets localhost + repo-local properties and ensures local admin in passwd
- entrypoint.d/05-configure-apache.sh - added `polarionSVN-local.conf` with `<Location /repo-local>` while leaving `polarionSVN.conf` untouched
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- Current Polarion default `/repo` block uses DBD with `polarion_internal.svnauthn`; custom overrides there are brittle and can regress auth
- `localhost` and `127.0.0.1` both serve `/repo-local/` correctly after the dedicated local endpoint is enabled
  **Open / Next steps**:
- Validate with a fresh browser session that no new `ISVNAuthentication provider did not provide credentials` entries are produced after login/navigation

---

## 2026-04-19 - Restored DB-backed SVN authentication for Polarion users

**Branch**: main
**What was done**: Investigated recurring SVN credential cancellation during logged-in UI requests and traced it to Apache auth mismatches, not repository reachability. Restored DBD-based auth in startup normalization so Polarion users are validated against the internal auth table instead of stale htpasswd-only entries.
**Changed files**:

- entrypoint.d/99-start-polarion.sh - switched /repo normalization to keep mod_authn_dbd with AuthBasicProvider dbd and ensured AuthDBDUserPWQuery is present
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- If Apache error.log contains AH01617 "Password Mismatch" for /repo/.polarion/user-management/users/<user>/page.xml, user SVN auth is out of sync with Polarion login credentials
- Removing AuthDBDUserPWQuery and forcing file-only auth can reintroduce ISVNAuthentication provider credential-cancel errors in UI flows
  **Open / Next steps**:
- Run one clean stop/start cycle to verify the fixed 99-start script applies end-to-end without ad-hoc container patching

---

## 2026-04-19 - Fixed Polarion SVN auth regression and stabilized installer automation

**Branch**: main
**What was done**: Investigated failing admin/admin login and missing SVN access rights after image rebuild. Updated startup scripts so SVN Apache auth is normalized after Polarion service start, enforced file-based SVN auth with stable access file path, and ensured admin user bootstrap in passwd. Also hardened install automation for PolarionALM_2512 and made Docker build tolerate installer exit-code variance while validating installed artifacts.
**Changed files**:

- entrypoint.d/05-configure-apache.sh - switched AuthzSVNAccessFile path to /srv/polarion/svn/access for correct runtime permissions
- entrypoint.d/99-start-polarion.sh - post-start re-normalization of polarionSVN.conf, DBD/LDAP auth cleanup, admin passwd bootstrap, Apache restart
- install.expect - resilient prompt-matching loop for Polarion installer automation
- Dockerfile - installer step now validates installed directories even if installer returns non-zero
- PROJECT_LOG.md - added this session log entry
  **New knowledge**:
- polarionSVN.conf may be generated or overwritten during Polarion startup, so auth normalization must run after service start
- /srv/polarion/svn/access is the effective access control file path for this image/runtime layout
- Polarion 2512 installer can report successful installation but still return non-zero in unattended builds; validating resulting installation directories is a safer build gate
  **Open / Next steps**:
- Consider removing sample-data installation during image build to reduce build time
- Optionally refine install.expect to force no on start-now prompt if future installer text changes

---
