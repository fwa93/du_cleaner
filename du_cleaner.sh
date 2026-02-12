#!/usr/bin/env bash
# quit script if any of the commands fails. Note that && commands should be in parentheses for this to work.
set -eo pipefail
trap 'exit_status="$?" && echo Failed on line: $LINENO at command: $BASH_COMMAND && echo "exit status $exit_status"' ERR

# The directory that contain subdirectories. The dubdirectories will be removed if old enough.
target="$1"
if ! [ -d "$target" ] || [ -z "$target" ] ; then
    if [ -z "$target" ]; then
        echo "please specify the target directory. E.g., ./du_cleaner.sh my_target/target_dir"
        exit 1
    fi
    echo "directory $target does not exist"
    exit 1
fi

if [ $# -ne 1 ]
then
 echo "Usage: ./du_cleaner.sh [my_target/target_dir]"
 exit 1
fi
# Thresholds
# If the available % is lower than this (or same), the cleaning starts.
perc_min=20
# If the available GB is lower (or same) than this, the cleaning starts.
gb_min=190

read tot used avai perc <<< $(df -BG . | awk 'NR==2 {print $2, $3, $4, $5}')

# Remove units
tot_gb=${tot%G}
avai_gb=${avai%G}
perc_used=${perc%\%}

echo $tot_gb
echo $avai_gb
echo $perc_used

# Calculate free percentage
free_perc=$((100 - $perc_used))

echo "Total: ${tot_gb}G"
echo "Free: ${avai_gb}G (${free_perc}% free)"

# Check conditions. Remove iname if we want all patterns in target.
if [ "$free_perc" -le "$perc_min" ] || [ "$avai_gb" -le "$gb_min" ]; then
    date
    echo "Low space detected. Will try to remove directories in $target"
    find "$target" -mindepth 1 -maxdepth 1 -type d -iname 'run_*' -mtime +14 -print  -exec rm -rf {} +
fi

echo "end of script"
