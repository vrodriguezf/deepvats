#!/bin/bash

# Define the lines to be added
lines_to_add=$(cat <<'EOF'

########## Avoid data leaks ##########
line_found=$(grep "^[[:space:]]*user: &wdb_user" ./nbs_pipeline/config/base.yaml)

if [ -z "$line_found" ]; then
    echo "User line not found."
    exit 1
else
    echo "User line found: '$line_found'"

    modified_line="    user: &wdb_user <your entity>"
    echo "--> Modified to: '    $modified_line'"
    
    sed -i "s|^\([[:space:]]*user: &wdb_user\).*|\1 <your entity> |" ./nbs_pipeline/config/base.yaml
    
    
    grep "user: &wdb_user" ./nbs_pipeline/config/base.yaml
fi

line_found=$(grep "^[[:space:]]*project_name: &wdb_project" ./nbs_pipeline/config/base.yaml)

if [ -z "$line_found" ]; then
    echo "Project line not found."
    exit 1
else
    echo "Project line found: '$line_found'"

    modified_line="    project_name: &wdb_project <your project>"
    echo "--> Modify to: '    $modified_line'"
    
    sed -i "s|^\([[:space:]]*project_name: &wdb_project\).*|\1 <your project>|" ./nbs_pipeline/config/base.yaml
    
    grep "project_name: &wdb_project" ./nbs_pipeline/config/base.yaml
fi

exec "$@"
EOF
)

# Define the line to be checked
line_to_check='line_found=$(grep "^[[:space:]]*user: &wdb_user" ./nbs_pipeline/config/base.yaml)'

# Check if the line already exists in the pre-commit file
if grep -Fxq "$line_to_check" $1/work/.git/hooks/pre-commit
then
    echo "Line already exists in pre-commit file."
else
    echo "Adding lines to pre-commit file."
    echo "$lines_to_add" >> $1/work/.git/hooks/pre-commit
fi