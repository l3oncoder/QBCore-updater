#!/bin/bash

if [ ! "$SHELL" == "/bin/bash" ]; then
	echo "This script MUST be ran using bash. Don't put \"sh\" at the start of your command!"
	exit 1
fi

# Written by RedHooman
# Idea by DistrictV

# Github API key goes here.
TOKEN=""

# Path to FiveM resources folder
FIVEM_HOME="/home/FiveM"
FIVEM_CACHE="${FIVEM_HOME}/cache"
FIVEM_RESOURCES="${FIVEM_HOME}/resources"
# Valid values: true, false (CASE SENSITIVE!)
FIVEM_REMOVE_CHAT_THEME="false"
# Valid values: true, false (CASE SENSITIVE!)
FIVEM_DOWLOAD_ARTIFACT="false"
# Valid values: true, false (CASE SENSITIVE!)
FIVEM_USE_CUSTOM_PATCH="false"
# Private Github repository containing custom patches. E.g. USERNAME/REPOSITORY.git. Patch example [qb]/qbx-core/config.lua would replace resources/[qb]/qbx-core/config.lua
FIVEM_CUSTOM_PATCH_REPO="USERNAME/REPOSITORY.git"
# Name of screen session.
FIVEM_SCREEN_NAME="FiveM"

# Stuff to remove before the update
CLEAN_FILES="${FIVEM_CACHE} ${FIVEM_RESOURCES}/[ox] ${FIVEM_RESOURCES}/[qb] ${FIVEM_RESOURCES}/[standalone] ${FIVEM_RESOURCES}/[cfx-default] ${FIVEM_RESOURCES}/[cfx-default-temp] ${FIVEM_RESOURCES}/[patch]"

# Stuff to ignore when downloading QB.
QB_IGNORE_REPOS="txAdminRecipe\|qb-commandbinding"

function downloadArtifact() {
	URL="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
	VERSION=$(curl  -sS "${URL}" | grep OPTIONAL  | sort | tail -1 | sed -n 's/.*LATEST OPTIONAL.."*//p' | sed 's/.$//')
	GETNEWVERSION=$(curl "${URL}" | sed -e 's/^<a href=["'"'"']//i' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' |  \
			grep "${VERSION}" | awk '{ print $2 }' | sed -n 's/.*href="..\([^"]*\).*/\1/p')
	NEWVERSION="${URL}${GETNEWVERSION}"

	echo "GETNEWVER:  ${GETNEWVERSION}"
	echo "NEWVERSION: ${NEWVERSION}"
	
	wget "${NEWVERSION}" -O "fx.tar.xz"
	
	echo "Extracting files..."
	tar xf "fx.tar.xz"
	rm "fx.tar.xz"
	
	echo "Removing old artifact instances..."
	rm -f /home/run.sh
	rm -Rf /home/alpine
	
	echo "Moving files to their corresponding location..."
	mv alpine run.sh /home
	
	echo "Done"
}

function getLatestDownloadLink() {
	# $1 = Github Repo
	curl -s -H "Accept: application/vnd.github+json" -H "Authorization: Bearer ${TOKEN}" "https://api.github.com/repos/${1}/releases/latest" | grep "browser_download_url" | cut -d '"' -f4
}

function downloadFileInstall() {
	# $1 = URL
	# $2 = Extraction destination
	
	if [[ "${1}" == "" ]]; then
		echo "No URL specified!"
	fi
	
	if [[ "${2}" == "" ]]; then
		echo "No extraction destination specified!"
	fi
	
	if [[ ! -d "${2}" ]]; then
		mkdir -p "${2}"
	fi
	
	FILENAME=$(basename "${1}")

	echo "File download URL: ${1}"
	echo "Name of file to download: ${FILENAME}"

	if [[ -f "${FILENAME}" ]]; then
		echo "Old download found. Removing..."
		rm -f "${FILENAME}"
	fi
	
	wget "${1}" -O "${FILENAME}"
	
	if [[ -f "${FILENAME}" ]]; then
		echo "Extracting file..."
		echo "Source: ${FILENAME}"
		echo "Destination: ${2}"
		unzip "${FILENAME}" -d "${2}"
		rm -f "${FILENAME}"
	else
		echo "Failed to download!"
		exit 1
	fi
}


# Kill FiveM screen
echo "Killing FiveM screen session..."
screen -S ${FIVEM_SCREEN_NAME} -X quit

echo -e "FIVEM HOME: ${FIVEM_HOME}\n\
FIVEM CACHE: ${FIVEM_CACHE}\n\
FIVEM RESOURCES: ${FIVEM_RESOURCES}"

# Delete old stuff.
echo "Deleting old resources..."

rm -Rf $CLEAN_FILES

if [[ ! -d "${FIVEM_RESOURCES}" ]]; then
	mkdir -p "${FIVEM_RESOURCES}"
fi

cd "${FIVEM_RESOURCES}"



downloadFileInstall $(getLatestDownloadLink "overextended/ox_lib") "${FIVEM_RESOURCES}/[ox]"
downloadFileInstall $(getLatestDownloadLink "overextended/ox_target") "${FIVEM_RESOURCES}/[ox]"
downloadFileInstall $(getLatestDownloadLink "overextended/oxmysql") "${FIVEM_RESOURCES}/[ox]"
downloadFileInstall $(getLatestDownloadLink "overextended/ox_doorlock") "${FIVEM_RESOURCES}/[ox]"


# QB related stuff
echo "Deleting 'qb' and 'standalone' resources..."
rm -Rf "${FIVEM_RESOURCES}/[standalone]" "${FIVEM_RESOURCES}/[qb]"

echo "Creating directories..."
mkdir -p "${FIVEM_RESOURCES}/[standalone]" "${FIVEM_RESOURCES}/[qb]"

echo "Cloning QB repositories..."
cd "${FIVEM_RESOURCES}/[standalone]"
curl -s https://api.github.com/orgs/Qbox-project/repos?per_page=200 | grep "clone_url" | cut -d '"' -f4 | grep -v "${QB_IGNORE_REPOS}" | xargs -n 1 git clone

echo "Moving files to their corresponding location..."
mv qb-* "${FIVEM_RESOURCES}/[qb]"

cd ..

# Now lets grab the latest FiveM files
echo "Cloning the CFX/FiveM repository..."

# Clone CFX into a temp directory, them move the resources into their final destination.
git clone https://github.com/citizenfx/cfx-server-data.git "${FIVEM_RESOURCES}/[cfx-default-temp]"
echo "Moving files to their corresponding location..."
mv ${FIVEM_RESOURCES}/\[cfx-default-temp\]/resources/ ${FIVEM_RESOURCES}/\[cfx-default\]/
rm -Rf "${FIVEM_RESOURCES}/[cfx-default-temp]"

if [[ "${FIVEM_REMOVE_CHAT_THEME}" == "true" ]]; then
	echo "Removing CFX chat theme..."
	rm -Rf "${FIVEM_RESOURCES}/[cfx-default]/[gameplay]/chat-theme-gtao"
fi

if [[ "${FIVEM_USE_CUSTOM_PATCH}" == "true" ]]; then
	#Apply our patches
	git clone "https://${TOKEN}@github.com/${FIVEM_CUSTOM_PATCH_REPO}" "${FIVEM_RESOURCES}/[patch]"
	cd "${FIVEM_RESOURCES}/[patch]"
	cp -r "[qb]" "${FIVEM_RESOURCES}"
	cd ..
	rm -Rf "${FIVEM_RESOURCES}/[patch]"
fi

cd "${FIVEM_HOME}"
if [[ "${FIVEM_DOWLOAD_ARTIFACT}" == "true" ]]; then
downloadArtifact
fi
# Run FiveM inside of screen
cd /home
screen -dmS ${FIVEM_SCREEN_NAME} bash run.sh;


