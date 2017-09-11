#!/bin/sh -e

printf "Heapsorting main.c..."
./test_heap < main.c > main.c.sorted
if LC_ALL=C sort < main.c | cmp - main.c.sorted; then
	echo " PASSED!"
	rm main.c.sorted
else
	echo " FAILED!"
	exit 1
fi
