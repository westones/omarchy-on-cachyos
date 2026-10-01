#!/bin/bash

# Target destination (relative to this script's location).
# The clone goes INSIDE the repo, next to bin/. Two levels up would land outside
# the repository — at $HOME/omarchy when the repo sits in $HOME, and at a
# non-existent or non-writable parent when it sits anywhere deeper. That is the
# "no such file or directory" the old path produced on a plain `git clone` into
# $HOME. The in-repo location is also what .gitignore's `omarchy/` rule expects.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/../omarchy"
REPO_URL="https://github.com/basecamp/omarchy"

# Fetch available stable version tags, filtering out pre-releases
echo "Fetching available stable releases from GitHub..."
mapfile -t ALL_TAGS < <(git ls-remote --tags --refs "$REPO_URL" 2>/dev/null | awk -F/ '{print $3}' | sort -rV)

# Filter out pre-release tags (containing -beta, -alpha, -rc, -dev, -pre, -next)
RELEASES=()
for tag in "${ALL_TAGS[@]}"; do
    if [[ ! "$tag" =~ -(beta|alpha|rc|dev|pre|next) ]]; then
        RELEASES+=("$tag")
    fi
done

# Offer the newest majors, not just the newest tags.
# Taking the 5 newest stable tags alone makes the previous major unreachable as
# soon as a new major ships (v4.0.4..v4.0.0 fill the whole list), which strands the
# v3 branch this script still implements. Take 3 from the newest major and 2 from
# the one before it, so both install modes stay reachable.
NEWEST_MAJOR=""
SECOND_MAJOR=""
for tag in "${RELEASES[@]}"; do
    major="${tag#v}"; major="${major%%.*}"
    if [ -z "$NEWEST_MAJOR" ]; then
        NEWEST_MAJOR="$major"
    elif [ "$major" != "$NEWEST_MAJOR" ] && [ -z "$SECOND_MAJOR" ]; then
        SECOND_MAJOR="$major"
    fi
done

PICKED=()
n_new=0
n_old=0
for tag in "${RELEASES[@]}"; do
    major="${tag#v}"; major="${major%%.*}"
    if [ "$major" = "$NEWEST_MAJOR" ]; then
        [ "$n_new" -ge 3 ] && continue
        n_new=$((n_new + 1))
    elif [ -n "$SECOND_MAJOR" ] && [ "$major" = "$SECOND_MAJOR" ]; then
        [ "$n_old" -ge 2 ] && continue
        n_old=$((n_old + 1))
    else
        continue
    fi
    PICKED+=("$tag")
done
RELEASES=("${PICKED[@]}")

echo "-----------------------------------------------"
echo "Select the Omarchy version you want to install:"
echo "-----------------------------------------------"
echo "1) Bleeding Edge (dev/main branch - Unstable)"

# Dynamically list the stable versions with major version indicator
for i in "${!RELEASES[@]}"; do
    TAG="${RELEASES[i]}"
    MAJOR="${TAG#v}"
    MAJOR="${MAJOR%%.*}"
    if [ "$MAJOR" -ge 4 ] 2>/dev/null; then
        LABEL="Stable Release (${TAG}) [v4 - packages]"
    else
        LABEL="Stable Release (${TAG}) [v3 - source]"
    fi
    echo "$((i+2))) $LABEL"
done

read -r -p "Enter your choice (1-$(( ${#RELEASES[@]} + 1 ))): " CHOICE

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt $(( ${#RELEASES[@]} + 1 )) ]; then
    echo "Invalid choice. Exiting."
    exit 1
fi

# Formulate arguments based on selection
if [ "$CHOICE" -eq 1 ] || [ -z "$CHOICE" ]; then
    BRANCH_ARGS=""
    SELECTED_TAG=""
    echo "Cloning bleeding-edge dev tree..."
else
    SELECTED_TAG="${RELEASES[$((CHOICE-2))]}"
    BRANCH_ARGS="--depth 1 -b $SELECTED_TAG"
    echo "Cloning stable version: $SELECTED_TAG..."
fi

# Detect major version for installer branching.
# For a pinned tag the major is in the tag name. For bleeding edge there is no tag
# to read, so leave it unset and resolve it from the clone below — hardcoding a
# major here would silently mis-branch whenever main moves to the next version.
if [ -n "$SELECTED_TAG" ]; then
    OMARCHY_VERSION_MAJOR="${SELECTED_TAG#v}"
    OMARCHY_VERSION_MAJOR="${OMARCHY_VERSION_MAJOR%%.*}"
else
    OMARCHY_VERSION_MAJOR=""
fi

# Export for the installer to use
export OMARCHY_VERSION_MAJOR
export SELECTED_TAG

# Ensure target directory is clean before git cloning to prevent fatal conflicts
if [ -d "$TARGET_DIR" ]; then
    echo ""
    echo "Warning: An existing installation directory was found at $TARGET_DIR"
    read -r -p "Would you like to delete it and proceed with a clean install? [y/N]: " CONFIRM

    if [[ "${CONFIRM,,}" =~ ^(y|yes)$ ]]; then
        echo "Cleaning up previous installation files at $TARGET_DIR..."
        rm -rf "$TARGET_DIR"
    else
        echo "Proceeding with existing files in $TARGET_DIR..."
        exit 0
    fi
fi

# Execute clean checkout bypassing standard detached HEAD advice warnings
echo "Cloning into $TARGET_DIR..."
if ! git -c advice.detachedHead=false clone $BRANCH_ARGS $REPO_URL "$TARGET_DIR"; then
    echo "Error: Failed to clone Omarchy repo."
    exit 1
fi

echo "Successfully cloned Omarchy repository layout."

# Bleeding edge: resolve the major from what we actually cloned. Upstream v4
# deleted the top-level install.sh, so its presence is the reliable signal.
if [ -z "$OMARCHY_VERSION_MAJOR" ]; then
    if [ -f "$TARGET_DIR/install.sh" ]; then
        OMARCHY_VERSION_MAJOR="3"
    else
        OMARCHY_VERSION_MAJOR="4"
    fi
    export OMARCHY_VERSION_MAJOR
fi
echo "Detected Omarchy major version: $OMARCHY_VERSION_MAJOR"
