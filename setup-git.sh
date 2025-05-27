#!/bin/bash

# Git setup script for Charity Router project

echo "Setting up git repository for Charity Router..."

# Add all our new files
echo "Adding files to git..."
git add .gitignore
git add .env.example
git add README.md
git add foundry.toml
git add .gitmodules
git add lib/
git add src/*.bak
git add test/*.bak
git add script/

# Check git status
echo "Current git status:"
git status

echo ""
echo "Files ready to commit:"
echo "- Updated .gitignore with comprehensive rules"
echo "- Added .env.example for environment setup"
echo "- Created project-specific README.md"
echo "- Foundry configuration and dependencies"
echo "- Moved default Counter files to .bak"
echo ""
echo "Run 'git commit -m \"Initial project setup with Foundry\"' to commit these changes"
