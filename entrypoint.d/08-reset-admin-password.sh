#!/bin/bash
# Polarion 2612+ generates a random admin password into its Secrets Manager at install time
# (polarion.admin.user.password.key) instead of the documented default "admin", which breaks
# /repo-local and every "admin/admin" convention of this image. While the stored hash still
# belongs to that generated secret (nobody changed the password), set it to "admin" again.
# A password changed in Polarion no longer matches the secret and is never touched.
# Skipped on versions without secrets-cli (2606 and older keep "admin" themselves).
SECRETS_CLI_DIR="${SECRETS_CLI_DIR:-/opt/polarion/polarion/secrets-cli}"
POLARION_PG="${POLARION_PG:-polarion:polarion@localhost:5433}"

reset_admin_password() {
	[ -f "$SECRETS_CLI_DIR/secrets-cli.jar" ] || return 0
	local pg_user="${POLARION_PG%%:*}" rest="${POLARION_PG#*:}"
	local pg_pass="${rest%%@*}" hostport="${rest#*@}"
	local psql_cmd=(psql -At -h "${hostport%%:*}" -p "${hostport##*:}" -U "$pg_user" -d polarion_system)
	local query="select password from polarion_internal.userauthn where username='admin'"
	local stored secret salt
	stored="$(PGPASSWORD="$pg_pass" "${psql_cmd[@]}" -c "$query" 2>/dev/null)" || return 0
	[ -n "$stored" ] || return 0
	[ "$stored" = "$(openssl passwd -apr1 -salt "$(cut -d'$' -f3 <<<"$stored")" admin)" ] && return 0
	secret="$(cd "$SECRETS_CLI_DIR" && java -jar secrets-cli.jar get --key polarion.admin.user.password.key --non-interactive 2>/dev/null | tail -n 1)"
	[ -n "$secret" ] || return 0
	salt="$(cut -d'$' -f3 <<<"$stored")"
	[ "$stored" = "$(openssl passwd -apr1 -salt "$salt" "$secret")" ] || return 0
	PGPASSWORD="$pg_pass" "${psql_cmd[@]}" \
		-c "update polarion_internal.userauthn set password='$(openssl passwd -apr1 admin)' where username='admin'" >/dev/null &&
		echo "Reset the generated admin password to the documented default (admin)."
}

reset_admin_password
