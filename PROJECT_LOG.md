# Project Log

Most recent entries appear first. Older entries may be moved to PROJECT_LOG_ARCHIVE.md.

---

<!-- entries below -->

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
