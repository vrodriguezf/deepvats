#!/bin/sh
echo "Files received:"
printf '%s\n' "$@"

for notebook in "$@"; do
    #--- Clean outputs
    #/usr/local/share/miniconda3/envs/env/bin/nbdev_clean --clear_all --fname "$notebook"
    #--- Do not clean outputs
    echo "--> Clean $notebook "
<<<<<<< HEAD
    /usr/local/share/miniconda3/envs/env/bin/nbdev_clean --clear_all --fname "$notebook"
=======
    /usr/local/share/miniconda3/envs/env/bin/nbdev_clean --fname "$notebook"
>>>>>>> chore-add-pre-commit-hooks-cleaned
    if [ $? -ne 0 ]; then
        echo "Error cleaning $notebook"
    fi
    echo "Clean $notebook -->"
done

exit 0