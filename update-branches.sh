#!/bin/bash

# Script to update all version branches with main branch changes
# while preserving the polarion-linux.zip file in each branch

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

# Function to update a single branch
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
    
    # Merge main into this branch
    log "Merging main into $branch..."
    if git merge main --no-edit; then
        log "Merge successful"
        
        # Restore the backed up polarion-linux.zip if it existed
        if [ "$BACKUP_EXISTS" = true ]; then
            debug "Restoring polarion-linux.zip for $branch"
            cp "/tmp/polarion-linux-${branch}.zip" "polarion-linux.zip"
            
            # Add and commit the restored file if there are changes
            if ! git diff --quiet polarion-linux.zip; then
                git add polarion-linux.zip
                git commit -m "Restore polarion-linux.zip for $branch after merge from main"
            fi
            
            # Clean up backup
            rm "/tmp/polarion-linux-${branch}.zip"
        fi
        
        # Push the updated branch
        log "Pushing updated $branch to remote..."
        git push origin "$branch"
        
        log "✅ Successfully updated $branch"
    else
        error "Merge failed for $branch. Please resolve conflicts manually."
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
