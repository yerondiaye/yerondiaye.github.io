#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

int main(int argc, char** argv) {
    struct stat statbuf;
    struct tm* tm = NULL;
    char buf[17];

    if (argc != 2) {
        fprintf(stderr, "usage: %s file\n", argv[0]);
        fprintf(stderr, "This command prints the mtime of file.\n");
        return EXIT_FAILURE;
    }

    /* Check for NULL argument */
    if (argv[1] == NULL || strlen(argv[1]) == 0) {
        fprintf(stderr, "Error: filename cannot be empty\n");
        return EXIT_FAILURE;
    }

    if (stat(argv[1], &statbuf) != 0) {
        fprintf(stderr, "Error: cannot stat '%s': %s\n", argv[1], strerror(errno));
        return EXIT_FAILURE;
    }

    tm = localtime(&(statbuf.st_mtime));
    if (tm == NULL) {
        fprintf(stderr, "Error: localtime failed for '%s'\n", argv[1]);
        return EXIT_FAILURE;
    }

    /* Buffer is 17 bytes, expected output is 16 chars + null terminator */
    if (strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M", tm) != 16) {
        fprintf(stderr, "Error: strftime failed for '%s'\n", argv[1]);
        return EXIT_FAILURE;
    }

    puts(buf);
    return EXIT_SUCCESS;
}
