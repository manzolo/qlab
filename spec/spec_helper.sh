# shellspec spec_helper

# Set QLAB_ROOT to the project root
QLAB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export QLAB_ROOT

# Source library files
for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [ -f "$lib_file" ] && . "$lib_file"
done
