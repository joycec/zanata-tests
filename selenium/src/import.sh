#!/bin/sh
# Import the sample projects

if [ -n "$ZANATA_URL" ]; then
   ZANATA_URL_BAK=$ZANATA_URL
fi

if [ -n "$TEST_CONFIG_FILE" ]; then
    source $TEST_CONFIG_FILE
else
    source ./test.cfg
fi

# restore back environment setting
if [ -n "$ZANATA_URL_BAK" ]; then
    ZANATA_URL=$ZANATA_URL_BAK
fi

ZANATA_PUBLICAN_LOG=`pwd`/zanata_publican.log

function FIND_PROGRAM(){
   _cmd=`which $1 2>/dev/null`
   if [ -z "${_cmd}" ] ; then
       echo "Error: $1 cannot be found in path!"
       exit 1
   fi
   echo ${_cmd}
}

function set_opts(){
    export ZANATA_PUBLICAN_COMMON_OPTS="--errors --debug --user admin --key ${APIKEY_admin}"
}

function upload_(){
    echo "       Uploading documents"
	_proj=$1
	_upload_dest="${ZANATA_URL}/${REST_PATH}${_proj}/iterations/i/${INIT_ITER}/documents"
	if [ $PYTHON_CLIENT -eq 1 ];then
		for doc in pot/*.pot; do
			echo "         Uploading $doc"
			${ZANATA_CLIENT_CMD} publican push --project $_proj --iteration "${INIT_ITER}" $doc >> ${ZANATA_PUBLICAN_LOG}
		done
	else
		echo "_upload_dest=${_upload_dest}"
		${ZANATA_CLIENT_CMD} upload ${ZANATA_PUBLICAN_COMMON_OPTS} -i --src . --dst "${_upload_dest}" >> ${ZANATA_PUBLICAN_LOG}
	fi
}


# has_project <proj_id> <cachefile>
function has_project(){
    proj_id=$1
    if [ $PYTHON_CLIENT -eq 1 ]; then
	_ret=`$ZANATA_CLIENT_CMD list | grep -e "Id:\s*${proj_id}"`
	if [ "${_ret}" = "" ]; then
	    echo "FALSE"
	else
	    echo "TRUE"
	fi
    fi
}

# Whether the current api key valid
function is_current_apikey_valid(){
    _apikey_file=$1
    if [ -f "${_apikey_file}" ];then
	echo "TRUE"
    else
	echo "FALSE"
    fi
}

PUBLICAN_CMD=`FIND_PROGRAM publican`
ZANATA_PYTHON_CLIENT=zanata
ZANATA_JAVA_CLIENT=zanata-publican
export PYTHON_CLIENT=0
while getopts "p" opt;	do
	case $opt in
		p)
			export PYTHON_CLIENT=1
			;;
		*)
			;;
	esac
done
shift $((OPTIND-1));
ACTION=$1
if [ $PYTHON_CLIENT -eq 1 ]; then
	ZANATA_CLIENT_CMD=`FIND_PROGRAM zanata`
else
	ZANATA_CLIENT_CMD=`FIND_PROGRAM zanata-publican`
fi

ret=`is_current_apikey_valid apikey.admin`
if [ "${ret}" = "TRUE" ]; then
    APIKEY_admin=`cat apikey.admin`
else
    source ./get_apikey.sh
fi

mkdir -p ${SAMPLE_PROJ_DIR}
rm -f ${FILES_PUBLICAN_LOG}

for pProj in $PUBLICAN_PROJECTS; do
    _proj=$(eval echo \$${pProj})

    echo "Processing project ${_proj}:${_proj_name}"

    _zanata_has_proj=`has_project ${_proj} tmp0.html`
    #echo "_zanata_has_proj=${_zanata_has_proj}"
    if [ "${_zanata_has_proj}" = "TRUE" ]; then
	if [ -z ${ACTION} ]; then
	    echo "  Zanata already has this project, skip importing."
	    continue
	fi
	echo "  Zanata has this project, start ${ACTION}."
	APIKEY_admin=`cat apikey.admin`
    else
	echo "  Zanata does not have this project, start importing."
    fi


    _clone_action=
    _update_action=
    _repo_cmd=$(eval echo \$${pProj}_REPO_TYPE)
    if [ "${_repo_cmd}" = "git" ]; then
	_clone_action="clone"
	_update_action="pull"
    elif [ "${_repo_cmd}" = "svn" ]; then
	_clone_action="co"
	_update_action="up"
    fi

    _proj_dir="${SAMPLE_PROJ_DIR}/${_proj}"

    if [ -z ${ACTION} ]; then
	if [ ! -d "${_proj_dir}" ]; then
	    echo "    ${_proj_dir} does not exist, clone now."
	    _proj_url=$(eval echo \$${pProj}_URL)
	    ${_repo_cmd} "${_clone_action}" "${_proj_url}" "${_proj_dir}"
	else
	    echo "    ${_proj_dir} exists, updating."
	    (cd ${_proj_dir}; ${_repo_cmd} "${_update_action}")
	fi
    fi

    pushd ${_proj_dir}
    rm -f ${ZANATA_PUBLICAN_LOG}
    if [ -z ${ACTION} ]; then
	if grep -e "brand:.*" publican.cfg ; then
	    # Remove brand
	    echo "    Removing brand."
	    mv publican.cfg publican.cfg.orig
	    sed -e 's/brand:.*//' publican.cfg.orig > publican.cfg
	fi

	if [ ! -d "pot" ]; then
	    echo "    pot does not exist, update_pot now!"
	    ${PUBLICAN_CMD} update_pot >> ${ZANATA_PUBLICAN_LOG}
	    touch pot
	fi

	if [ "publican.cfg" -nt "pot" ]; then
	    echo "    "publican.cfg" is newer than "pot", update_pot needed."
	    ${PUBLICAN_CMD} update_pot >> ${ZANATA_PUBLICAN_LOG}
	fi

	${PUBLICAN_CMD}  update_po --langs="${LANGS}" >> ${ZANATA_PUBLICAN_LOG}

	_proj_name=$(eval echo \$${pProj}_NAME)
	_proj_desc=$(eval echo \$${pProj}_DESC)
    fi

    if [  -z "${ACTION}" -o "${ACTION}" = "createproj" ]; then
	echo "   Creating project ${_proj_name}"
	if [ $PYTHON_CLIENT -eq 1 ];then
		${ZANATA_CLIENT_CMD} project create  "${_proj}" --name "${_proj_name}" --description "${_proj_name}" >> ${ZANATA_PUBLICAN_LOG}
	else
		${ZANATA_CLIENT_CMD} createproj ${ZANATA_PUBLICAN_COMMON_OPTS} --zanata "${ZANATA_URL}" --proj "${_proj}" --name "${_proj_name}" --desc "${_proj_name}" >> ${ZANATA_PUBLICAN_LOG}
	fi

	if [ $? -ne 0 ]; then
	    echo "Error occurs, skip following steps!"
	    continue
	fi
    fi

    if [ -z "${ACTION}" -o "${ACTION}" = "createiter" ]; then
	echo "       Creating project iteration as ${INIT_ITER_NAME}"
	if [ $PYTHON_CLIENT -eq 1 ];then
		${ZANATA_CLIENT_CMD} iteration create "${INIT_ITER}" --project "${_proj}" --name "${INIT_ITER_NAME}" --description "${INIT_ITER_DESC}" >> ${ZANATA_PUBLICAN_LOG}
	else
		${ZANATA_CLIENT_CMD} createiter ${ZANATA_PUBLICAN_COMMON_OPTS} --zanata "${ZANATA_URL}" --proj "${_proj}" --iter "${INIT_ITER}" --name "${INIT_ITER_NAME}" --desc "${INIT_ITER_DESC}" >> ${ZANATA_PUBLICAN_LOG}
	fi

	if [ $? -ne 0 ]; then
	    echo "Error occurs, skip following steps!"
	    continue
	fi
    fi

    if [ -z "${ACTION}" -o "${ACTION}"="upload" ]; then
	upload_ ${_proj}
    fi

    popd
done
rm -f tmp?.*
echo "Done!"

