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

# check if CONFIG_SET is set
if [ -z "${CONFIG_SET}" ]; then
    echo -e "${GREEN}CONFIG_SET is not set, repository root will be used"
    CONFIG_SET=""
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

# Move the contents of the specified CONFIG_SET to the INSTALL_DIR
if [ -n "${CONFIG_SET}" ]; then
    echo -e "${GREEN}Moving contents of ${TEMP_DIR}/${CONFIG_SET} to ${INSTALL_DIR}"
    cp -r ${TEMP_DIR}/${CONFIG_SET}/* ${INSTALL_DIR}
fi



### START CUSTOM SCRIPT ###



# Reset game config to default to ensure overrides can be disabled or removed
echo -e "${GREEN}Resetting server config to defaults"
cp ${TEMP_DIR}/Defaults.json ${INSTALL_DIR}/Config.json

# Check if OVERRIDES_PATH is set and apply overrides to server config from the specified file
if [ -n "${OVERRIDES_PATH}" ]; then
    echo -e "${GREEN}OVERRIDES_PATH is set"

    if [ -f "${TEMP_DIR}/Overrides/${OVERRIDES_PATH}" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/Overrides/${OVERRIDES_PATH}"

        jq '. * input' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/Overrides/${OVERRIDES_PATH} > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
    else
        echo -e "${GREEN}${TEMP_DIR}/${OVERRIDES_PATH} not found, skipping overrides"
    fi
fi

# Check if LOOTMX is set to true and adjust loot spawn values in server config
if [ "${LOOTMX}" != "0" ]; then
    echo -e "${GREEN}LOOTMX is enabled"

    if [ -f "${TEMP_DIR}/LootMx/overrides.json" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/LootMx/overrides.json"

        jq '. * input' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/LootMx/overrides.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
    else
        echo -e "${GREEN}${TEMP_DIR}/LootMx/overrides.json not found, skipping overrides"
    fi
fi

# Check if KITS is set to true and install kits plugin/required configs
if [ "${KITS}" = "1" ]; then
    echo -e "${GREEN}KITS is enabled"

    cp ${TEMP_DIR}/Kits/Kits.dll ${INSTALL_DIR}/Rocket/Plugins
    cp ${TEMP_DIR}/Kits/Kits/* ${INSTALL_DIR}/Rocket/Plugins/Kits
else
    echo -e "${GREEN}KITS is disabled, skipping installation and removing existing plugin"

    rm -f ${INSTALL_DIR}/Rocket/Plugins/Kits.dll
    rm -rf ${INSTALL_DIR}/Rocket/Plugins/Kits
fi



### END CUSTOM SCRIPT ###



# Clean up: remove the temporary directory
echo -e "${GREEN}Cleaning up: removing temporary directory ${TEMP_DIR}"
rm -rf ${TEMP_DIR}

# Log end of script
echo -e "${GREEN}Repository clone script completed"