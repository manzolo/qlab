# shellspec spec_helper

# Set QLAB_ROOT to the project root
# SHELLSPEC_PROJECT_ROOT is provided by shellspec
QLAB_ROOT="${SHELLSPEC_PROJECT_ROOT:-.}"
export QLAB_ROOT

# Source library files
for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [ -f "$lib_file" ] && . "$lib_file"
done
