#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define MAX_PATTERN_LEN 4096

int main(int argc, char** argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s string_to_replace file_to_insert < "
                "source_file > output_file\n", argv[0]);
        fprintf(stderr, "This command replaces string_to_replace in "
                "source_file with the content of file_to_insert "
                "(except for a trailing newline) and writes the "
                "output to output_file.\n");
        return EXIT_FAILURE;
    }

    /* Validate arguments */
    if (argv[1] == NULL || strlen(argv[1]) == 0) {
        fprintf(stderr, "Error: string_to_replace cannot be empty\n");
        return EXIT_FAILURE;
    }

    if (argv[2] == NULL || strlen(argv[2]) == 0) {
        fprintf(stderr, "Error: file_to_insert cannot be empty\n");
        return EXIT_FAILURE;
    }

    size_t l = strlen(argv[1]);

    /* Prevent excessive memory usage from very long patterns */
    if (l > MAX_PATTERN_LEN) {
        fprintf(stderr, "Error: string_to_replace too long (max %d bytes)\n",
                MAX_PATTERN_LEN);
        return EXIT_FAILURE;
    }

    /* Allocate bucket on heap instead of stack to avoid VLA issues */
    char* bucket = malloc(l);
    if (!bucket) {
        fprintf(stderr, "Error: memory allocation failed\n");
        return EXIT_FAILURE;
    }

    size_t n, j, pos = 0;
    char buf[BUFSIZ];

    while ((n = fread(buf, sizeof(char), BUFSIZ, stdin)) > 0) {
        for (j = 0; j < n; j++) {
            if (buf[j] == argv[1][pos]) {
                bucket[pos] = buf[j];
                pos++;

                if (pos == l) {
                    int hold = 0;
                    char buf2[BUFSIZ];
                    FILE* fp = fopen(argv[2], "rb");
                    size_t m;

                    if (!fp) {
                        fprintf(stderr, "Error: could not open file '%s': %s\n",
                                argv[2], strerror(errno));
                        free(bucket);
                        exit(EXIT_FAILURE);
                    }

                    while ((m = fread(buf2, sizeof(char), BUFSIZ, fp))) {
                        if (hold) {
                            if (fputc('\n', stdout) == EOF) {
                                fprintf(stderr, "Error: write failed\n");
                                fclose(fp);
                                free(bucket);
                                exit(EXIT_FAILURE);
                            }
                            hold = 0;
                        }

                        if (buf2[m - 1] == '\n') {
                            m--;
                            hold = 1;
                        }

                        if (fwrite(buf2, sizeof(char), m, stdout) != m) {
                            fprintf(stderr, "Error: write failed\n");
                            fclose(fp);
                            free(bucket);
                            exit(EXIT_FAILURE);
                        }
                    }

                    /* Check for read errors */
                    if (ferror(fp)) {
                        fprintf(stderr, "Error: failed to read from '%s'\n", argv[2]);
                        fclose(fp);
                        free(bucket);
                        exit(EXIT_FAILURE);
                    }

                    fclose(fp);
                    pos = 0;
                }
            }
            else {
                if (pos > 0 && fwrite(bucket, sizeof(char), pos, stdout) != pos) {
                    fprintf(stderr, "Error: write failed\n");
                    free(bucket);
                    exit(EXIT_FAILURE);
                }
                if (fputc(buf[j], stdout) == EOF) {
                    fprintf(stderr, "Error: write failed\n");
                    free(bucket);
                    exit(EXIT_FAILURE);
                }
                pos = 0;
            }
        }
    }

    /* Check for read errors on stdin */
    if (ferror(stdin)) {
        fprintf(stderr, "Error: failed to read from stdin\n");
        free(bucket);
        return EXIT_FAILURE;
    }

    free(bucket);
    return EXIT_SUCCESS;
}
