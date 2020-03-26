#!/bin/bash

arr=(4 5 2 0 3)
len=${#arr[@]}
echo Unsorted: ${arr[@]}

for i in $(seq 1 $len); do
    
    for j in $(seq 0 $((len-i))); do
    
    if [[ ${arr[j]} -gt ${arr[j+1]} ]]; then

      tmp=${arr[j]}
      arr[j]=${arr[j+1]}
      arr[j+1]=$tmp

    fi
    
    echo Temp: ${arr[@]}

  done
done

echo Sorted: ${arr[@]}
