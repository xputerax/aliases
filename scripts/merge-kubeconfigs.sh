#!/usr/bin/env bash
# merge-kubeconfigs.sh — combine all kubeconfigs in ~/.kube/config.d into one file
#
# Usage:
#   ~/.kube/merge-kubeconfigs.sh [output-file]     (default: ~/.kube/config)
#
# Env overrides:
#   KUBECONFIG_DIR    source directory        (default: ~/.kube/config.d)
#   DEFAULT_CONTEXT   context to make current (default: k0s-homelab)
#
# - Files are merged in glob order; invalid/unreadable files are skipped.
# - Credentials are embedded (--flatten) so the result is fully self-contained.
# - Output is written atomically with 0600 perms (it contains private keys).

set -euo pipefail

CONFIG_DIR="${KUBECONFIG_DIR:-$HOME/.kube/config.d}"
OUTPUT="${1:-$HOME/.kube/config}"
DEFAULT_CONTEXT="${DEFAULT_CONTEXT:-k0s}"

command -v kubectl >/dev/null 2>&1 || { echo "error: kubectl not found" >&2; exit 1; }
[[ -d "$CONFIG_DIR" ]] || { echo "error: $CONFIG_DIR does not exist" >&2; exit 1; }

# Collect valid kubeconfig files, colon-joined for $KUBECONFIG
shopt -s nullglob
merge_list=""
for f in "$CONFIG_DIR"/*; do
  [[ -f "$f" && -r "$f" ]] || continue
  if ! kubectl --kubeconfig "$f" config get-contexts >/dev/null 2>&1; then
    echo "warn: skipping invalid kubeconfig: $f" >&2
    continue
  fi
  merge_list="${merge_list:+$merge_list:}$f"
done
shopt -u nullglob
[[ -n "$merge_list" ]] || { echo "error: no kubeconfigs found in $CONFIG_DIR" >&2; exit 1; }

# Merge + flatten into a temp file first (atomic-ish, no half-written output)
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
KUBECONFIG="$merge_list" kubectl config view --flatten > "$tmp"

# Pick current-context: preferred default if present, else first file's choice
if ! kubectl --kubeconfig "$tmp" config get-contexts -o name 2>/dev/null | grep -qx "$DEFAULT_CONTEXT"; then
  DEFAULT_CONTEXT="$(kubectl --kubeconfig "$tmp" config current-context 2>/dev/null || true)"
fi
[[ -n "$DEFAULT_CONTEXT" ]] && kubectl --kubeconfig "$tmp" config use-context "$DEFAULT_CONTEXT" >/dev/null

# Back up an existing output once, then install with tight perms
if [[ -f "$OUTPUT" && ! -f "$OUTPUT.bak" ]]; then
  cp "$OUTPUT" "$OUTPUT.bak" && chmod 600 "$OUTPUT.bak"
fi
chmod 600 "$tmp"
mv "$tmp" "$OUTPUT"
trap - EXIT

echo "merged $(awk -F: '{print NF}' <<<"$merge_list") configs -> $OUTPUT (current-context: $DEFAULT_CONTEXT)"
kubectl --kubeconfig "$OUTPUT" config get-contexts
