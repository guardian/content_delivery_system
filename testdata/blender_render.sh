#!/bin/bash
#first simple test using the docs at http://wiki.blender.org/index.php/Doc:2.4/Manual/Render/Command_Line to do blender render

#set one of these to tell us what to render
#BLENDER_FILE=""
#BLENDER_SCRIPT=""

JUMP_FRAMES=1	#render every JUMP_FRAMES frames. 1=> render all frames.
START_FRAME=""
END_FRAME=""

RENDER_PATH="/srv/Proxies2/DevSystem/BlenderRender/Outputs"
RENDER_FORMAT="QUICKTIME"
RENDER_OUT="${RENDER_PATH}/$1"

THREADS=20

INSTALLPATH="/opt/blender"

if [ ! -d ${RENDER_PATH} ]; then
	mkdir -p "${RENDER_PATH}"
	if [ "$?" != "0" ]; then
		echo Unable to set up render directory at ${RENDER_PATH}
		exit 3
	fi
fi

if [ ! -x "${INSTALLPATH}/blender" ]; then
	echo Unable to find the blender executable in ${INSTALLPATH}
	exit 1
fi

OPTIONS=""
if [ "${BLENDER_FILE}" != "" ]; then
	OPTIONS=${OPTIONS} -b "${BLENDER_FILE}"
elif [ "${BLENDER_SCRIPT}" != "" ]; then
	OPTIONS=${OPTIONS} -P "${BLENDER_SCRIPT}"
else
	echo You must specify either BLENDER_FILE or BLENDER_SCRIPT environment variables
	exit 2
fi

if [ "${JUMP_FRAMES}" != "" ]; then
	OPTIONS=${OPTIONS} -j ${JUMP_FRAMES}
fi

if [ "${THREADS}" != "" ]; then
	OPTIONS=${OPTIONS} -t ${THREADS}
fi

OPTIONS=${OPTIONS} -x 1 -o "${RENDER_FILE}"

