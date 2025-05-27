#!/bin/bash
cd /Users/z/Documents/github/clicker-contract
echo "=== Current working directory ==="
pwd
echo ""

echo "=== Git status ==="
git status
echo ""

echo "=== Current files in project ==="
ls -la
echo ""

echo "=== Ready to commit? Run these commands: ==="
echo "git add ."
echo "git commit -m 'Initial project setup with Foundry and enhanced configuration'"
echo "git remote add origin <your-remote-repo-url>"
echo "git push -u origin main"
