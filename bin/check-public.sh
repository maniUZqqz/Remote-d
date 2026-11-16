#!/bin/bash
# PC Remote: refuses to let secrets into this PUBLIC repository. Used as the git pre-commit hook (install.sh sets it up);
# also runnable by hand:  bin/check-public.sh   (checks everything that is tracked or staged).
# Forbidden: the live state (invites/, nodes/, out/, invites.json), filled-in setup files, any private key, a filled-in
# invitation key inside the setup template (the template only holds the placeholder).
cd "$(dirname "$0")/.." || exit 2
M1="-----BEGIN"                      # built from pieces so that this file does not match itself
M2="PRIVATE KEY"
B64="LS0tLS1CRUdJTi""B"              # base64 of "-----BEGIN" (a private key embedded as base64, like the setup file does)
bad=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    invites/*|nodes/*|out/*|invites.json|*.zip|*_key|*_key.pub|*.pem|PC-Remote-Setup-*.bat|*/PC-Remote-Setup-*.bat)
      echo "check-public: NOT ALLOWED in the repository: $f"; bad=1; continue ;;
  esac
  blob=$(git show ":$f" 2>/dev/null) || continue
  if printf '%s' "$blob" | grep -q -E -e "${M1}[A-Z ]*${M2}" -e "${B64}"; then
    echo "check-public: $f contains a private key (or a setup file with an embedded key)"; bad=1
  fi
done < <(git ls-files)
[ "$bad" = 0 ] || { echo "check-public: refused. Keys and invitation files are handed over privately, never committed."; exit 1; }
exit 0
