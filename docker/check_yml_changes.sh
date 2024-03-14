#!/bin/bash

# Obtain a list of modified .yml/.yaml files
MODIFIED_YML_FILES=$(git diff --cached --name-only | grep -E '\.(yml|yaml)$')

echo "Modified files: "$(git diff --cached --name-only)
echo "Modified yml files: "$MODIFIED_YML_FILES
# Check if the list is empty
if [ -z "$MODIFIED_YML_FILES" ]; then
    echo "No yaml files modified, proceed with the commit"
    exit 0
else
    # .yml files have been modified, ask the user
    echo "The following .yml files have been modified:"
    echo "$MODIFIED_YML_FILES"
    read -p "Do you wish to retain the changes in these .yml files? [y/n]: " response

    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        # The user does not wish to retain the changes, remove the .yml files from the commit
        echo "Removing the .yml files from the staging area..."
        for file in $MODIFIED_YML_FILES; do
            git reset HEAD "$file"
            echo "File removed from commit: $file"
        done
        echo "Commit cancelled | Proceed with your commit for the other files."
        exit 1
    else
        # The user wishes to retain the changes, continue with the commit
        exit 0
    fi
fi