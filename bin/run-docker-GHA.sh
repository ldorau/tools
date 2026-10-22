#!/bin/bash -e

SCRIPT="/tmp/run-docker-script-$$.sh"
echo "#!/bin/bash -x" >> $SCRIPT
chmod +x $SCRIPT

function get_line() {
	PATTERN=$1
	grep -nH -e "$PATTERN" $FILE | cut -d: -f2
}

function export_all_vars() {
	echo ">>>>>>>>>>>>>>>>>> export_all_vars $1 $2" >> $LOG
	S_BEG=$(get_line "$1")
	S_END=$(get_line "$2")
	S_END=$((S_END - 1))
	N=$((S_END - S_BEG))
	head -n $S_END $FILE | tail -n $N | grep -e ':' | grep -v -e '${{' | \
	while IFS='' read -r line || [[ -n "$line" ]]; do
		name=$(echo $line | awk '{print $1}' | cut -d: -f1)
		val=$(echo $line | awk '{print $2}')
		echo "export $name=$val" >> $SCRIPT
		echo "export $name=$val" >> $LOG
	done
}

function export_one_line() {
	echo ">>>>>>>>>>>>>>>>>> export_one_line $1 $2 $3" >> $LOG
	S_BEG=$(get_line "$1")
	S_END=$(get_line "$2")
	S_END=$((S_END - 1))
	LINES=$((S_END - S_BEG))
	N=$3
	VARS=$(head -n $S_END $FILE | tail -n $LINES | grep -e '=' | head -n $N | tail -n1 | cut -d'"' -f2)

	echo
	echo "INFO: running matrix #$N: $VARS"

	for var in $VARS; do
		echo "export $var" >> $SCRIPT
		echo "export $var" >> $LOG
	done
}

function execute_all_commands() {
	S_BEG=$(get_line "$1")
	[ "$S_BEG" == "" ] && return
	if [ "$2" != "" ]; then
		S_END=$(get_line "$2")
		if [ "$S_END" == "" ]; then
			S_END=$(cat $FILE | wc -l)
			S_END=$((S_END + 1))
		else
			S_END=$((S_END - 1))
		fi
	else
		S_END=$(cat $FILE | wc -l)
		S_END=$((S_END + 1))
	fi
	N=$((S_END - S_BEG - 1))

	echo ">>>>>>>>>>>>>>>>>> export_all_commands $1 $2" >> $LOG
	TMP_SH="/tmp/run-docker-temp-$$.sh"
	head -n $S_END $FILE | tail -n $N | grep -e 'run:' | cut -d: -f2 | sed 's/\${{ matrix.CONFIG }}//g' | \
	while IFS='' read -r line || [[ -n "$line" ]]; do
		echo "$line" >> $LOG
		cat $SCRIPT > $TMP_SH
		echo "RUNNING COMMAND: $line"
		echo "echo RUNNING COMMAND: $line" >> $TMP_SH
		echo $line >> $TMP_SH
		chmod +x $TMP_SH
		$TMP_SH
		RV=$?
		rm -f $TMP_SH
		echo "RETURN CODE = $RV (command: $line)" || true
		[ $RV -ne 0 ] && echo "return $RV" && return $RV
	done || true
}

function set_global_variables() {
	export_all_vars "env:" "matrix:"
}

function set_matrix_variables() {
	export_one_line "matrix:" "steps:" $1
}

function execute_steps() {
	execute_all_commands "steps:" ""
}

function print_usage() {
	S_BEG=$(get_line "matrix:")
	S_END=$(get_line "steps:")
	S_END=$((S_END - 1))
	N=$((S_END - S_BEG))
	TMPF=$(mktemp)
	head -n $S_END $FILE | tail -n $LINES | grep -e '=' | head -n $N | cut -d'"' -f2 > $TMPF
	M=$(cat $TMPF | wc -l)
	echo "Usage: $(basename $0) <matrix number>"
	echo "ERROR: no matrix number given! There are $M entries in the matrix:"
	for ((i = 1; i <= $M; i++)); do
		echo -n "   $i)"
		cat $TMPF | head -n$i | tail -n1 | sed 's/   - //g'
	done
}

function print_disk_usage() {
	[ $1 -ne 0 ] && cat $LOG
	echo
	echo "END OF IMAGE: ${OS}:${OS_VER}"
	echo
	echo "To check all images run:"
	echo "$ sudo docker images -a"
	echo "Number of 'none' images: $(sudo docker images -a | grep none | wc -l)"
	echo
	echo "Current disk usage of Docker images:"
	sudo du -sh /var/lib/docker/overlay2
	rm -rf $TEST_DIR
	exit $1
}

############################################################################################

PWD=$(pwd)
[ "$2" == "" ] && FILE=$PWD/gha.yml || FILE=$2

if [ ! -f $FILE ]; then
	echo "ERROR: cannot find $FILE file!"
	echo "Expected format:"
	echo -e "env:\n...\nmatrix:\n...\nsteps:\n..."
	exit 1
fi

if [ "$1" == "" ]; then
	print_usage
	exit 1
fi

MATRIX=$1

TEST_DIR=/tmp/gha-$(basename $PWD)-$MATRIX-$$
LOG=$TEST_DIR.log
rm -rf $TEST_DIR $LOG

echo "Logging to: $LOG"
echo "Cloning the repo to $TEST_DIR ..."
git clone $PWD $TEST_DIR

cd $TEST_DIR
git config --global --add safe.directory $TEST_DIR
chown -R 1000:1000 $(pwd)

GITHUB_REPO=$(cat $FILE | grep -e "GITHUB_REPO" | awk '{print $2}')

###############################################################
# source gha.yml and run GHA build
###############################################################

set_global_variables
set_matrix_variables $MATRIX
echo "export HOST_WORKDIR=$TEST_DIR" >> $SCRIPT
echo "export GITHUB_ACTIONS=yes" >> $SCRIPT
execute_steps || print_disk_usage 1
print_disk_usage 0
