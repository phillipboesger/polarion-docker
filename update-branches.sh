#!/bin/bash

# Script to update all version branches with main branch changes
# while preserving the polarion-linux.zip file in each branch
# Uses a smarter approach to avoid merge conflicts

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository"
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
log "Current branch: $CURRENT_BRANCH"

# Make sure we're on main
if [ "$CURRENT_BRANCH" != "main" ]; then
    log "Switching to main branch..."
    git checkout main
fi

# Pull latest changes
log "Pulling latest changes from main..."
git pull origin main

# Get all remote branches that match v* pattern
log "Fetching all remote branches..."
git fetch --all

# Get list of version branches (v*)
VERSION_BRANCHES=$(git branch -r | grep -E 'origin/v[0-9]+$' | sed 's|origin/||' | sort)

if [ -z "$VERSION_BRANCHES" ]; then
    warn "No version branches found (pattern: v*)"
    exit 0
fi

log "Found version branches:"
echo "$VERSION_BRANCHES" | sed 's/^/  - /'

# Confirm before proceeding
echo
warn "This will update all version branches with changes from main branch."
warn "The polarion-linux.zip file in each branch will be preserved."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Operation cancelled"
    exit 0
fi

# Function to update a single branch using a fresh approach
update_branch() {
    local branch="$1"
    
    log "Updating branch: $branch"
    
    # Checkout the version branch
    git checkout "$branch"
    
    # Check if polarion-linux.zip exists and back it up
    if [ -f "polarion-linux.zip" ]; then
        debug "Backing up polarion-linux.zip from $branch"
        cp "polarion-linux.zip" "/tmp/polarion-linux-${branch}.zip"
        BACKUP_EXISTS=true
    else
        warn "No polarion-linux.zip found in $branch"
        BACKUP_EXISTS=false
    fi
    
    # Instead of merging, we'll replace all files except polarion-linux.zip
    debug "Replacing files from main (except polarion-linux.zip)..."
    
    # Get list of files from main branch (excluding polarion-linux.zip)
    git checkout main -- . || true
    git reset HEAD polarion-linux.zip 2>/dev/null || true
    
    # Restore the backed up polarion-linux.zip if it existed
    if [ "$BACKUP_EXISTS" = true ]; then
        debug "Restoring polarion-linux.zip for $branch"
        cp "/tmp/polarion-linux-${branch}.zip" "polarion-linux.zip"
        rm "/tmp/polarion-linux-${branch}.zip"
    fi
    
    # Check if there are any changes to commit
    if ! git diff --quiet || ! git diff --cached --quiet; then
        log "Committing updates for $branch..."
        git add .
        git commit -m "Update $branch with latest changes from main

- Updated configuration and scripts from main branch
- Preserved version-specific polarion-linux.zip file
- Updated RAM defaults to 4GB"
        
        # Push the updated branch
        log "Pushing updated $branch to remote..."
        git push origin "$branch"
        
        log "✅ Successfully updated $branch"
    else
        log "📝 No changes needed for $branch"
    fi
    
    echo
}

# Update each version branch
for branch in $VERSION_BRANCHES; do
    update_branch "$branch"
done

# Return to main branch
log "Returning to main branch..."
git checkout main

log "🎉 All version branches have been updated successfully!"
log ""
log "Summary:"
echo "$VERSION_BRANCHES" | sed 's/^/  ✅ /'
log ""
log "All branches now have the latest changes from main while preserving their specific polarion-linux.zip files."
