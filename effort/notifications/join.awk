#!/usr/bin/awk -f
BEGIN { FS = "</td><td>" }

function print_prev(cur1) {
    if (cur1 != prev1)
        prev0 = prev1 "(" dict[prev1] ")" substr(prev0, length(prev1) + 1)
    print prev0
}

!dictdone && !dictfile { dictfile = FILENAME }
FILENAME != dictfile { dictdone = 1 }
!dictdone { dict[$1] = $2; next }

FNR != 1 { print_prev($1) }
{ prev0 = $0; prev1 = $1 }
END { print_prev(prev1 " ") }
