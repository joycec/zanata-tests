#!/usr/bin/env sh
# If publican.cfg exists, this script does a publican update,
# otherwise do nothing.
scriptDir=`dirname $0`
langs=$1

_langs=`echo $langs | sed -e 's/;/ /g'`
_first=1
_langs_final=
for l in ${_langs};
do
    lDir=`${scriptDir}/find_valid_langs.sh . $l`
    if [ -n "$lDir" ];then
	if [ "$_first" = "0" ]; then
	    _langs_final="${_langs_final},"
	else
	    _first=0
	fi
	_l=`basename $lDir`
	_langs_final="${_langs_final}${_l}"
    fi
done
#echo "_langs_final=${_langs_final}"

if [ -e publican.cfg ]; then
    if [ -n `which publican` ] ; then
	sed -e "s/brand:.*//" publican.cfg > publican.cfg.striped
	publican update_pot --config publican.cfg.striped \
	&& publican update_po --config publican.cfg.striped --langs ${_langs_final}
    else
	echo "[Error] publican is not installed" > /dev/stderr
	exit 1
    fi
else
    touch publican.cfg.striped
fi
exit 0

