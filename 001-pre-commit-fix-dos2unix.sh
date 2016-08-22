#!/bin/sh

find * -type f | while read line; do
	file "$line" | grep -q text && {
		dos2unix "$line"
	}
done
