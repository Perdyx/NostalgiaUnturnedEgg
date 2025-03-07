#!/bin/bash
sleep 1

cd /home/container

TEMP_DIR="tmp/repo"
# set the echo color to green
GREEN='\033[0;32m'


# check if REPOSITORY_URL is set
if [ -z "${REPOSITORY_URL}" ]; then
    echo -e "${GREEN}REPOSITORY_URL is not set, skipping repository clone"
    exit 0
fi

# check if REPOSITORY_BRANCH is set
if [ -z "${REPOSITORY_BRANCH}" ]; then
    echo -e "${GREEN}REPOSITORY_BRANCH is not set, defaulting to 'master'"
    REPOSITORY_BRANCH="master"
fi

# check if REPOSITORY_DIR is set
if [ -z "${REPOSITORY_DIR}" ]; then
    echo -e "${GREEN}REPOSITORY_DIR is not set, repository root will be used"
    REPOSITORY_DIR=""
fi

# check if REPOSITORY_ACCESS_TOKEN is set
if [ -z "${REPOSITORY_ACCESS_TOKEN}" ]; then
    echo -e "${GREEN}REPOSITORY_ACCESS_TOKEN is not set, cloning without authentication"
fi

# check if INSTALL_DIR is set
if [ -z "${INSTALL_DIR}" ]; then
    echo -e "${GREEN}INSTALL_DIR is not set, defaulting to 'Servers/unturned'"
    INSTALL_DIR="Servers/unturned"
fi

# remove temp dir if exists
if [ -d "${TEMP_DIR}" ]; then
    rm -rf ${TEMP_DIR}
    echo -e "${GREEN}Temporary directory ${TEMP_DIR} has been removed."
fi

# Log start of script
echo -e "${GREEN}Starting repository clone script"

# Clone the repository into a temporary directory
echo -e "${GREEN}Cloning repository from ${REPOSITORY_URL} (branch: ${REPOSITORY_BRANCH}) into temporary directory ${TEMP_DIR}"
if [ -n "${REPOSITORY_ACCESS_TOKEN}" ]; then
    git clone -b ${REPOSITORY_BRANCH} https://${REPOSITORY_ACCESS_TOKEN}@${REPOSITORY_URL} ${TEMP_DIR}
else
    git clone -b ${REPOSITORY_BRANCH} https://${REPOSITORY_URL} ${TEMP_DIR}
fi

# If clone failed, log error and cancel sync
if [ $? -ne 0 ]; then
    echo -e "${GREEN}Repository clone failed, aborting sync"
    exit 1
fi

echo "${GREEN}Repository successfully cloned to ${TEMP_DIR}"

# Check if ADDON_LOOT2X is set to true and adjust loot spawn values in server config
if [ "${ADDON_LOOT2X}" = "true" ]; then
    echo -e "${GREEN}ADDON_LOOT2X is enabled"

    if [ -f "${TEMP_DIR}/Loot2x/overrides.json" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/Loot2x/overrides.json"
        jq -s '.[0] * .[1]' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/Loot2x/overrides.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
    else
        echo -e "${GREEN}${TEMP_DIR}/Loot2x/overrides.json not found, skipping overrides"
    fi
fi

# Check if ADDON_KITS is set to true and install kits plugin/required configs
if [ "${ADDON_KITS}" = "true" ]; then
    echo -e "${GREEN}ADDON_KITS is enabled"

    cp ${TEMP_DIR}/Kits/Kits.dll ${INSTALL_DIR}/Rocket/Plugins

    mkdir -p ${INSTALL_DIR}/Rocket/Plugins/Kits
    cp -r ${TEMP_DIR}/Kits/Kits ${INSTALL_DIR}/Rocket/Plugins/Kits
fi

# Check if ${COLOUR}, ${SERVER_ICON}, and ${SERVER_DESCRIPTION} are set and adjust server config
if [ -n "${COLOUR}" ] && [ -n "${SERVER_ICON}" ] && [ -n "${SERVER_DESCRIPTION}" ]; then
    echo -e "${GREEN}Updating server configuration with provided icon, description, and colour"
    
    jq --arg icon "${SERVER_ICON}" --arg desc "<color=#${COLOUR}>${SERVER_DESCRIPTION}</color>" \
       '.Browser.Icon = $icon | .Browser.Thumbnail = $icon | .Browser.Desc_Hint = $desc | .Browser.Desc_Server_List = $desc' \
       ${INSTALL_DIR}/Config.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
else
    echo -e "${GREEN}COLOUR, SERVER_ICON, or SERVER_DESCRIPTION not set, skipping server config update"
fi

# Delete paths specified in Delete array else log that it doesn't exist
for DELETE_PATH in ${DELETE_PATHS}; do
    if [ -d "${DELETE_PATH}" ]; then
        echo -e "${GREEN}Deleting ${DELETE_PATH}"
        rm -rf ${DELETE_PATH}
    else
        echo -e "${GREEN}${DELETE_PATH} does not exist, skipping deletion"
    fi
done

# Create the INSTALL_DIR if it doesn't exist
if [ ! -d "${INSTALL_DIR}" ]; then
    echo -e "${GREEN}Creating install directory ${INSTALL_DIR}"
    mkdir -p ${INSTALL_DIR}
fi

# Move the contents of the specified REPOSITORY_DIR to the INSTALL_DIR
if [ -n "${REPOSITORY_DIR}" ]; then
    echo -e "${GREEN}Moving contents of ${TEMP_DIR}/${REPOSITORY_DIR} to ${INSTALL_DIR}"
    ## use cp command
    cp -r ${TEMP_DIR}/${REPOSITORY_DIR}/* ${INSTALL_DIR}
fi

# Clean up: remove the temporary directory
echo -e "${GREEN}Cleaning up: removing temporary directory ${TEMP_DIR}"
rm -rf ${TEMP_DIR}

# Log end of script
echo -e "${GREEN}Repository clone script completed"