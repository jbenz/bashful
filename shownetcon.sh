#!/bin/bash

sudo lsof -i TCP -s TCP:ESTABLISHED -nP | awk '
NR == 1 { print; next }
{
    output = ""
    i = 1
    while (i <= length($0)) {
        # Look for IP pattern
        if (match(substr($0, i), /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
            # Add text before IP
            output = output substr($0, i, RSTART - 1)
            ip = substr($0, i + RSTART - 1, RLENGTH)
            
            # Color based on IP
            if (ip ~ /^162\.248\.246\.[0-7]$/) {
                output = output "\033[90m" ip "\033[0m"
            } else if (ip ~ /^10\.20\.0\./) {
                output = output "\033[37m" ip "\033[0m"
            } else if (ip ~ /^(10\.|192\.168\.|172\.)/) {
                output = output ip
            } else {
                # External IP - bright red background with white text
                output = output "\033[41;97m" ip "\033[0m"
            }
            
            i = i + RSTART + RLENGTH - 1
        } else {
            output = output substr($0, i)
            break
        }
    }
    
    # Color ESTABLISHED
    gsub(/ESTABLISHED/, "\033[32mESTABLISHED\033[0m", output)
    
    print output
}
'
