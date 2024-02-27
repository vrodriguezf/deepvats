#!/bin/sh
echo "Files received:"
printf '%s\n' "$@"

for notebook in "$@"; do
    #--- Clean outputs
    #/usr/local/share/miniconda3/envs/env/bin/nbdev_clean --clear_all --fname "$notebook"
    #--- Do not clean outputs
    echo "--> Clean $notebook "
    /usr/local/share/miniconda3/envs/env/bin/nbdev_clean --clear_all --fname "$notebook"
    if [ $? -ne 0 ]; then
        echo "Error cleaning $notebook"
    fi
    echo "Clean $notebook -->"
done

echo "Files cleaned"

exit 0