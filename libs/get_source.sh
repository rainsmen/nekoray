#!/bin/bash
set -e

source libs/env_deploy.sh
source libs/get_source_env.sh

# sing-box is now pulled from upstream module (v1.13.19) via go.mod require.
# No local clones needed — libneko dependency has been removed.

echo "==> Sources ready (sing-box v$COMMIT_SING_BOX via go.mod)"
