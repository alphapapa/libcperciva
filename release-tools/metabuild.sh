#!/bin/sh

D=$1
MAKEBSD=$2
CFLAGS_HARDCODED=$3

OUT=Makefile

# Check environment
if [ -z "$CPP" ]; then
	echo "Need CPP environment variable."
	exit 1
fi

# Check command-line arguments
if [ "$#" -ne 3 ]; then
	echo "Usage: $0 DIR MAKEBSD CFLAGS_HARDCODED"
	exit 1
fi

# Set up directories
cd ${D}
SUBDIR_DEPTH=`${MAKEBSD} -V SUBDIR_DEPTH`

# Set up *-config.h so that we don't have missing headers
rm -f ${SUBDIR_DEPTH}/cpusupport-config.h
touch ${SUBDIR_DEPTH}/cpusupport-config.h
rm -f ${SUBDIR_DEPTH}/apisupport-config.h
touch ${SUBDIR_DEPTH}/apisupport-config.h

copyvar() {
	var=$1
	if [ -n "`${MAKEBSD} -V $var`" ]; then
		printf "%s=" "$var" >> $OUT
		${MAKEBSD} -V $var >> $OUT
	fi
}

add_makefile_prog() {
	if [ `${MAKEBSD} -V NOINST` ]; then
		cat ${SUBDIR_DEPTH}/Makefile.prog |		\
		    perl -0pe 's/(install:.*?)\n\n//s' >> $OUT
	else
		cat ${SUBDIR_DEPTH}/Makefile.prog >> $OUT
	fi
}

add_object_files() {
	# Set up useful variables
	OBJ=$(${MAKEBSD} -V SRCS |				\
	    sed -e 's| apisupport-config.h||' |			\
	    sed -e 's| cpusupport-config.h||' |			\
	    tr ' ' '\n' |					\
	    sed -E 's/.c$/.o/' )
	CPP_SUPP="-DCPUSUPPORT_CONFIG_FILE=\"cpusupport-config.h\" -DAPISUPPORT_CONFIG_FILE=\"apisupport-config.h\""
	CPP_ARGS_FIXED="-std=c99 ${CPP_SUPP} -I${SUBDIR_DEPTH} -MM"
	OUT_CC_BEGIN="\${CC} \${CFLAGS_POSIX} ${CFLAGS_HARDCODED}"
	OUT_CC_MID="-I${SUBDIR_DEPTH} \${IDIRS} \${CPPFLAGS} \${CFLAGS}"

	# Generate build instructions for each object
	for F in $OBJ; do
		S=`${MAKEBSD} source-${F}`
		CF=`${MAKEBSD} cflags-${F}`
		IDIRS=`${MAKEBSD} -V IDIRS`
		# Get the build instructions, then remove newlines, condense
		# multiple spaces, remove line continuations, and replace the
		# final space with a newline.
		${CPP} ${S} ${CPP_ARGS_FIXED} ${IDIRS} -MT ${F} |	\
		    tr '\n' ' ' |					\
		    tr -s ' '	|					\
		    sed -e 's| \\ | |g' |				\
		    sed -e 's| $||g'
		printf "\n"
		echo "	${OUT_CC_BEGIN} ${CF} ${OUT_CC_MID} -c ${S} -o ${F}"
	done >> $OUT
}

# Add header and variables
echo '.POSIX:' > $OUT
echo '# AUTOGENERATED FILE, DO NOT EDIT' >> $OUT
copyvar PROG
copyvar MAN1
# SRCS is tricker to handle, as we need to remove any -config.h from the list.
if [ -n "`${MAKEBSD} -V SRCS`" ]; then
	printf "SRCS=" >> $OUT
	${MAKEBSD} -V SRCS |				\
	    sed -e 's| apisupport-config.h||' |		\
	    sed -e 's| cpusupport-config.h||' >> $OUT
fi
copyvar IDIRS
copyvar LDADD_REQ
copyvar SUBDIR_DEPTH
printf "RELATIVE_DIR=$D\n" >> $OUT

# Add all, install, clean, $PROG
if [ -n "`${MAKEBSD} -V SRCS`" ]; then
	add_makefile_prog
else
	printf "\nall:\n\ttrue\n\nclean:\n\ttrue\n" >> $OUT
fi

# Add all object files (if applicable)
if [ -n "`${MAKEBSD} -V SRCS`" ]; then
	add_object_files
fi

# Add test (if applicable)
if grep -q "test:" Makefile.BSD ; then
	printf "\n" >> $OUT
	awk '/test:/, /^$/' Makefile.BSD |			\
	    awk '$1' >> $OUT
fi

# Add all_extra (if applicable)
if grep -q "all_extra:" Makefile.BSD ; then
	printf "\n" >> $OUT
	awk '/all_extra:/, /^$/' Makefile.BSD |		\
	    awk '$1' >> $OUT
	sed -e 's/${MAKE} ${PROG}/${MAKE} ${PROG} all_extra/'	\
	    Makefile > Makefile.new
	mv Makefile.new Makefile
fi

# Add clean_extra (if applicable)
if grep -q "clean_extra:" Makefile.BSD ; then
	printf "\n" >> $OUT
	awk '/clean_extra:/, /^$/' Makefile.BSD |		\
	    awk '$1' >> $OUT
	awk '/clean:/ {print $0 "\tclean_extra";next}{print}'	\
	    Makefile > Makefile.new
	mv Makefile.new Makefile
fi

# Clean up *-config.h files
rm -f ${SUBDIR_DEPTH}/cpusupport-config.h
rm -f ${SUBDIR_DEPTH}/apisupport-config.h
