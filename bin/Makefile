CC = cc
CFLAGS = -Os -std=c99 -pedantic -Wall -Wextra -Werror -Wformat=2 -Wformat-security \
		 -Wstrict-prototypes -fstack-protector-strong -D_FORTIFY_SOURCE=2
LDFLAGS = -s

.PHONY: all clean check

all: replace mtime

replace: replace.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o replace replace.c

mtime: mtime.c
	$(CC) $(CFLAGS) $(LDFLAGS) -D_XOPEN_SOURCE=500 -o mtime mtime.c

check: replace mtime
	@echo "Checking binaries exist and are executable..."
	@test -x replace || (echo "Error: replace not executable" && exit 1)
	@test -x mtime || (echo "Error: mtime not executable" && exit 1)
	@echo "All checks passed."

clean:
	rm -f replace mtime
