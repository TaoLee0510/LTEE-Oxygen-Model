#!/usr/bin/env bash
set -euo pipefail

active="${LTEE_CONTAINER_RUNTIME_ACTIVE:-${O2SD_CONTAINER_RUNTIME_ACTIVE:-}}"
case "$(printf '%s' "${active}" | tr '[:upper:]' '[:lower:]')" in
  true|t|1|yes|y) ;;
  *) echo "Zenodo downloads must run inside the locked analysis container." >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "${script_dir}/util/workflow/fetch_zenodo_inputs.py" "$@"
