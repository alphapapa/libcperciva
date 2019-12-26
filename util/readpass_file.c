#include <stdio.h>
#include <string.h>

#include "insecure_memzero.h"
#include "warnp.h"

#include "readpass.h"

/* Maximum line length. */
#define MAXPASSLEN 2048

/**
 * readpass_file(passwd, filename):
 * Read a passphrase from ${filename} and return it as a malloced
 * NUL-terminated string via ${passwd}.  Produce an error if the file is more
 * than 2048 chracters, or if it contains any newline \n or \r\n characters
 * other than at the end of the file.  Do not include the \n or \r\n
 * characters in the passphrase.
 */
int
readpass_file(char ** passwd, const char * filename)
{
	char passwd_staging[MAXPASSLEN];
	FILE * fp;
	size_t eol_pos;
	size_t len_f;

	/* Open file and read data. */
	if ((fp = fopen(filename, "r")) == NULL) {
		warnp("fopen");
		goto err0;
	}

	/* Read from the file. */
	if ((len_f = fread(passwd_staging, 1, MAXPASSLEN, fp)) == 0) {
		if (ferror(fp)) {
			warn0("fread");
			goto err2;
		}
	}

	/* Mark the string ending. */
	passwd_staging[len_f] = '\0';

	/* Sanity check: we should be at the end of the file. */
	if (feof(fp) == 0) {
		warn0("file is too large: %s", filename);
		goto err2;
	}

	/* We're finished with the file. */
	if (fclose(fp)) {
		warnp("fclose");
		goto err1;
	}

	if (len_f > 0) {
		/* Find the first EOL character and truncate. */
		eol_pos = strcspn(passwd_staging, "\n");
		if (eol_pos < len_f - 1) {
			warn0("more than 1 line in %s", filename);
			goto err1;
		}
		passwd_staging[eol_pos] = '\0';
	}

	if (len_f > 1) {
		/* Remove \r if it was the penultimate character. */
		eol_pos = strcspn(passwd_staging, "\r");
		if (eol_pos < len_f - 2) {
			warn0("unexpected \\r in %s", filename);
			goto err1;
		}
		passwd_staging[eol_pos] = '\0';
	}

	/* Copy password to output. */
	if ((*passwd = strdup(passwd_staging)) == NULL) {
	    	warnp("strdup");
		goto err1;
	}

	/* Clean up temporary copy. */
	insecure_memzero(&passwd_staging, MAXPASSLEN);

	/* Success! */
	return (0);

err2:
	fclose(fp);
err1:
	insecure_memzero(&passwd_staging, MAXPASSLEN);
err0:
	/* Failure! */
	return (-1);
}
