#!/usr/bin/env bash
my_temp=$(mktemp -d )
# quit script if any of the commands fails. Note that && commands should be in parentheses for this to work.
set -eo pipefail
trap 'exit_status="$?" && echo Failed on line: $LINENO at command: $BASH_COMMAND && rm -r  $my_temp && echo "exit status $exit_status"' ERR

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
  elif [ $target == "/" ]; then
    echo "please specify a target that is not root"
    exit 1
  fi
done
# Thresholds THESE CAN BE CHANGED
# If the available % is lower than this (or same), the cleaning starts.
#perc_min=20
perc_min=99
# If the available GB is lower (or same) than this, the cleaning starts.
gb_min=190


# The directory that contain subdirectories. The subdirectories will be removed if old enough.
targets="$@"

c=0
for target in "$@" ; do
  my_temp2="$my_temp/$(basename "$target")"
  mkdir "$my_temp2"
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
    find "$target" -mindepth 1 -maxdepth 1 -type d -iname 'run_*' -mtime +30  -exec realpath {} + > "$my_temp2/find_output.txt"
    if [ -f "$my_temp2/find_output.txt" ]; then
      for i in $(cat "$my_temp2/find_output.txt") ; do
        if [ -f "$i/.done" ] && [ -d "$i" ] && [ -n "$i" ]; then
          echo "$(basename "$i")" >> "$my_temp2/find_output2.txt"
          echo "$i" >> "$my_temp2/find_output2_realpath.txt"
        fi

      done
      if [ -f "$my_temp2/find_output2.txt" ]; then
        find_output=$(cat $my_temp2/find_output2.txt | wc -l)
      else
        find_output=0
      fi
      if [ "$find_output" -eq 0 ]; then
        echo "No directories will be deleted (Likely not old enough. modify the mtime parameter?)"
        echo ""
      else
        echo "The following directories will be deleted"
        cat "$my_temp2/find_output2_realpath.txt"
        for j in $(cat "$my_temp2/find_output2.txt"); do
          echo "this is j $j"
          find "$target" -mindepth 1 -maxdepth 1 -type d -name "$j" -mtime +30   -exec rm -rf {} +
          echo ""
        done
      fi
    else
      echo "No directories will be deleted (Likely not old enough. modify the mtime parameter?)"
      echo ""
    fi

  fi
done

rm -r "$my_temp"
echo "end of script"
