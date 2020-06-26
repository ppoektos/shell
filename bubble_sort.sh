#!/bin/bash

arr=(5 4 3 2 1)
len=${#arr[@]}
echo Unsorted: ${arr[@]}

for i in $(seq 1 $len); do
    
    for ((j=0 ; j<$((len-i)) ; j++)); 
    
    if [[ ${arr[j]} -gt ${arr[j+1]} ]]; then

      tmp=${arr[j]}
      arr[j]=${arr[j+1]}
      arr[j+1]=$tmp

    fi
    
    echo Temp: ${arr[@]}

  done
done

echo Sorted: ${arr[@]}
