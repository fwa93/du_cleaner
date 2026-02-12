#!/usr/bin/env bash
# quit script if any of the commands fails. Note that && commands should be in parentheses for this to work.
set -eo pipefail
trap 'exit_status="$?" && echo Failed on line: $LINENO at command: $BASH_COMMAND && echo "exit status $exit_status"' ERR

if ! [ $# -ge 1 ]
then
 echo "Usage: ./du_cleaner.sh [my_target/target_dir] [my_target/target_dir2] "
 exit 1
fi

for target in "$@" ; do
  if ! [ -d "$target" ] ; then
    echo "directory $target does not exist"
    exit 1
  elif [ -z "$target" ]; then
    echo "please specify the target directories. E.g., ./du_cleaner.sh my_target/target_dir my_target/target_dir2"
    exit 1
  fi
done
# Thresholds THESE CAN BE CHANGED
# If the available % is lower than this (or same), the cleaning starts.
perc_min=99
# If the available GB is lower (or same) than this, the cleaning starts.
gb_min=190


# The directory that contain subdirectories. The subdirectories will be removed if old enough.
targets="$@"

c=0
for target in "$@" ; do
  read tot used avai perc <<< $(df -BG . | awk 'NR==2 {print $2, $3, $4, $5}')

  # Remove units
  tot_gb=${tot%G}
  avai_gb=${avai%G}
  perc_used=${perc%\%}


  # Calculate free percentage
  free_perc=$((100 - $perc_used))

  while [ $c -lt 1 ]; do
    echo "Total: ${tot_gb}G"
    echo "Free: ${avai_gb}G (${free_perc}% free)"
    c=$((c + 1))
  done

  # Check conditions. Remove iname if we want all patterns in target.
  if [ "$free_perc" -le "$perc_min" ] || [ "$avai_gb" -le "$gb_min" ]; then
    date
    if [ $c -lt 2 ]; then
      echo "Low space detected"
      c=$((c + 1))
    fi
    echo "Will try to remove directories in $target"
    #find "$target" -mindepth 1 -maxdepth 1 -type d -iname 'run_*' -mtime +14 -print  -exec realpath {} +
    echo ""
    find_output=$(find "$target" -mindepth 1 -maxdepth 1 -type d -iname 'run_*' -mtime +14 -print  -exec realpath {} + | wc -l)
    if [ "$find_output" -eq 0 ]; then
      echo "No directories will be deleted (Likely not old enough. modify the mtime parameter?)"
      echo ""
    else
      echo "The following directories will be deleted"
      find "$target" -mindepth 1 -maxdepth 1 -type d -iname 'run_*' -mtime +14 -print  -exec rm -rf {} +
      echo ""
    fi

  fi
done


echo "end of script"
