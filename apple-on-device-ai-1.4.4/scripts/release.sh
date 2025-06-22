#!/usr/bin/env bash

set -euo pipefail

# Release script for @meridius-labs/apple-on-device-ai
echo "🚀 Preparing release for @meridius-labs/apple-on-device-ai"

# Check if we're on main/master branch
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    echo "❌ Must be on main/master branch to release. Current: $BRANCH"
    exit 1
fi

# Check if working directory is clean
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Working directory is not clean. Please commit or stash changes."
    exit 1
fi

# Parse version type (patch, minor, major)
VERSION_TYPE=${1:-patch}
if [[ ! "$VERSION_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo "❌ Invalid version type: $VERSION_TYPE"
    echo "Usage: $0 [patch|minor|major]"
    exit 1
fi

echo "📦 Building project..."
bun run clean
bun run build

echo "🧪 Testing build..."
bun run test

echo "📝 Bumping version ($VERSION_TYPE)..."
# Get current version from package.json
CURRENT_VERSION=$(node -p "require('./package.json').version")
echo "Current version: $CURRENT_VERSION"

# Use npm to bump version (it handles semver properly)
npm version $VERSION_TYPE --no-git-tag-version

NEW_VERSION=$(node -p "require('./package.json').version")
echo "New version: $NEW_VERSION"

# Commit version bump
git add package.json
git commit -m "chore: bump version to $NEW_VERSION"

# Create and push tag
git tag "v$NEW_VERSION"
git push origin HEAD
git push origin "v$NEW_VERSION"

echo "✅ Release v$NEW_VERSION created!"
echo "🚀 GitHub Actions will handle the npm publish automatically" 