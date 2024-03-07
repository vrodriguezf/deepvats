#!/bin/bash

# Obtain a list of modified .yml files
MODIFIED_YML_FILES=$(git diff --cached --name-only | grep '\.yml\?$')

echo "Modified .yml files:"
# Check if the list is empty
if [ -z "$MODIFIED_YML_FILES" ]; then
    read -p "No yaml files modified, proceed with the commit"
    exit 0
else
    # .yml files have been modified, ask the user
    read rp "The following .yml files have been modified:"
    echo "$MODIFIED_YML_FILES"
    read -p "Do you wish to retain the changes in these .yml files? [y/n]: " response

    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        # The user does not wish to retain the changes, remove the .yml files from the commit
        read -p "Removing the .yml files from the staging area..."
        for file in $MODIFIED_YML_FILES; do
            git reset HEAD "$file"
            echo "File removed from commit: $file"
        done
        read -p "Proceed with your commit for the other files."
        exit 1
    else
        # The user wishes to retain the changes, continue with the commit
        exit 0
    fi
fi