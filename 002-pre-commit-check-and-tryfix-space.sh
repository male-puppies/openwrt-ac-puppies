#!/bin/sh
#

#git diff-index --check --cached HEAD --
git diff-index --check HEAD --

git diff-index --check HEAD -- | sed '/^[+-]/d' | sed -E 's/:[0-9]+:.*//' | sort | uniq | while read line; do
	sed -E 's/[[:space:]]*$//' -i "$line"
	echo auto fixing "$line"
done
