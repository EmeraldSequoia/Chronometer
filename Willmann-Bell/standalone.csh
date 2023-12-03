#!/bin/csh -f

gcc -c -x objective-c -std=c99 -g -DSTANDALONE -I../Classes ../Classes/ECAstronomyCache.m
gcc -c -x objective-c -std=c99 -g -DSTANDALONE -I../Classes ECWillmannBell.m
gcc -o test ECWillmannBell.o ECAstronomyCache.o && ./test


