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

# Read egg-config.json file in CONFIG_SET and delete all paths specified in Delete array, if CONFIG_SET is not specified then read egg-config.json file in TEMP_DIR
if [ -n "${CONFIG_SET}" ]; then
    echo -e "${GREEN}Reading egg-config.json file in ${TEMP_DIR}/${CONFIG_SET}"
    DELETE_PATHS=$(jq -r '.Delete[]' ${TEMP_DIR}/${CONFIG_SET}/egg-config.json)
else
    echo "${GREEN}Reading egg-config.json file in ${TEMP_DIR}"
    DELETE_PATHS=$(jq -r '.Delete[]' ${TEMP_DIR}/egg-config.json)
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



### START CUSTOM SCRIPT ###



# Apply egg-config.json
if [ -f "${TEMP_DIR}/egg-config.json" ]; then
    echo -e "${GREEN}Copying ${TEMP_DIR}/egg-config.json to ${INSTALL_DIR}/egg-config.json"

    cp ${TEMP_DIR}/egg-config.json ${INSTALL_DIR}/egg-config.json
else
    echo -e "${GREEN}${TEMP_DIR}/egg-config.json not found, skipping"
fi

# Check if CONFIG_OVERRIDES is set and apply overrides to server config from the specified file
if [ -n "${CONFIG_OVERRIDES}" ]; then
    echo -e "${GREEN}CONFIG_OVERRIDES is set"

    if [ -f "${TEMP_DIR}/Overrides/Config/${CONFIG_OVERRIDES}.json" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/Overrides/Config/${CONFIG_OVERRIDES}.json"

        jq '. * input' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/Overrides/Config/${CONFIG_OVERRIDES}.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
    else
        echo -e "${GREEN}${TEMP_DIR}/Overrides/Config/${CONFIG_OVERRIDES}.json not found, skipping config overrides"
    fi
fi

# Check if GAMEPLAY_OVERRIDES is set and apply overrides to server config from the specified file
if [ -f "${TEMP_DIR}/Gameplay/${GAMEPLAY_OVERRIDES}.json" ]; then
    echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/Gameplay/${GAMEPLAY_OVERRIDES}.json"

    jq '. * input' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/Gameplay/${GAMEPLAY_OVERRIDES}.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
else
    echo -e "${GREEN}${TEMP_DIR}/Gameplay/${GAMEPLAY_OVERRIDES}.json not found, skipping gameplay overrides"
fi

# Check if LOOTMX is set and adjust loot spawn values in server config
if [  "${LOOTMX}" == "1x" ]; then
    echo -e "${GREEN}LOOTMX is disabled, skipping loot spawn adjustments"
else
    echo -e "${GREEN}LOOTMX is enabled"

    if [ -f "${TEMP_DIR}/LootMx/${LOOTMX}.json" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/Config.json with ${TEMP_DIR}/LootMx/${LOOTMX}.json"

        jq '. * input' ${INSTALL_DIR}/Config.json ${TEMP_DIR}/LootMx/${LOOTMX}.json > ${INSTALL_DIR}/Config.tmp.json && mv ${INSTALL_DIR}/Config.tmp.json ${INSTALL_DIR}/Config.json
    else
        echo -e "${GREEN}${TEMP_DIR}/LootMx/${LOOTMX}.json not found, skipping overrides"
    fi
fi

# Check if WORKSHOP is set and apply overrides to workshop config from the specified file
if [ -n "${WORKSHOP}" ]; then
    echo -e "${GREEN}Workshop config overrides found, applying workshop overrides"

    if [ -f "${TEMP_DIR}/Overrides/Config/${OVERRIDES}.json" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/WorkshopDownloadConfig.json with ${TEMP_DIR}/Overrides/Workshop/${WORKSHOP}.json"

        jq '. * input' ${INSTALL_DIR}/WorkshopDownloadConfig.json ${TEMP_DIR}/Overrides/Workshop/${WORKSHOP}.json > ${INSTALL_DIR}/WorkshopDownloadConfig.tmp.json && mv ${INSTALL_DIR}/WorkshopDownloadConfig.tmp.json ${INSTALL_DIR}/WorkshopDownloadConfig.json
    else
        echo -e "${GREEN}${TEMP_DIR}/Overrides/Workshop/${WORKSHOP}.json not found, skipping workshop overrides"
    fi
fi

# Move the contents of the specified ROCKET_DIR to the INSTALL_DIR
if [ -n "${ROCKET_DIR}" ]; then
    echo -e "${GREEN}Moving contents of ${TEMP_DIR}/Rocket/${ROCKET_DIR} to ${INSTALL_DIR}/Rocket/"
    cp -r ${TEMP_DIR}/Rocket/${ROCKET_DIR}/* ${INSTALL_DIR}/Rocket/
fi

# Check if KITS is set to true and install kits plugin/required configs. If false, remove kits plugin and configs
if [ "${KITS}" == "1" ]; then
    echo -e "${GREEN}KITS is enabled"

    cp ${TEMP_DIR}/Kits/Kits.dll ${INSTALL_DIR}/Rocket/Plugins
    
    mkdir -p ${INSTALL_DIR}/Rocket/Plugins/Kits
    cp ${TEMP_DIR}/Kits/Kits/* ${INSTALL_DIR}/Rocket/Plugins/Kits
else
    echo -e "${GREEN}KITS is disabled, skipping installation"
fi



### END CUSTOM SCRIPT ###



# Clean up: remove the temporary directory
echo -e "${GREEN}Cleaning up: removing temporary directory ${TEMP_DIR}"
rm -rf ${TEMP_DIR}

# Log end of script
echo -e "${GREEN}Repository clone script completed"