#!/bin/bash

#from http://stackoverflow.com/questions/3915040/bash-fish-command-to-print-absolute-path-to-a-file
function abspath() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
        # dir
        (cd "$1"; pwd)
    elif [ -f "$1" ]; then
        # file
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}

BASEPATH=$(dirname $(abspath "${BASH_SOURCE%}"))
BASEPATH="${BASEPATH}/.."

#echo ${BASH_SOURCE}
echo Running in ${BASEPATH}

#Step one - validate Ruby code
HAVE_FAILURE=0
FAILED_VALIDATION=()
for x in `find "${BASEPATH}" -type f -iname \*.rb`; do
    echo `basename $x`
    ruby -c "$x"
    if [ "$?" != "0" ]; then
        FAILED_VALIDATION+=("$x");
        HAVE_FAILURE=1;
    fi
done

#Step two - validate Perl code
declare -x PERL5LIB="${BASEPATH}/CDS":"${BASEPATH}/CDS/CDS"
for x in `find "${BASEPATH}" -type f -iname \*.pl`; do
    echo `basename $x`
    perl -c "$x"
    if [ "$?" != "0" ]; then
        FAILED_VALIDATION+=("$x");
        HAVE_FAILURE=1;
    fi
done

if [ "${HAVE_FAILURE}" != "0" ]; then
    echo "-------------------------------------"
    echo 'ERROR! Some modules failed code validation.'
    echo "The following methods failed code validation: "
    echo ${FAILED_VALIDATION[*]}
else
    echo "All perl and ruby modules have passed code sanity check, but this doesn't yet mean that they'll work properly"
fi

exit ${HAVE_FAILURE}