#!/bin/bash

sleep 1

cd /home/container

TEMP_DIR="tmp/repo"
# Set the echo color to green
GREEN='\033[0;32m'

# Check if REPOSITORY_URL is set
if [ -z "${REPOSITORY_URL}" ]; then
    echo -e "${GREEN}REPOSITORY_URL is not set, skipping repository clone"
    exit 0
fi

# Check if REPOSITORY_BRANCH is set
if [ -z "${REPOSITORY_BRANCH}" ]; then
    echo -e "${GREEN}REPOSITORY_BRANCH is not set, defaulting to 'main'"
    REPOSITORY_BRANCH="main"
fi

# Check if REPOSITORY_ACCESS_TOKEN is set
if [ -z "${REPOSITORY_ACCESS_TOKEN}" ]; then
    echo -e "${GREEN}REPOSITORY_ACCESS_TOKEN is not set, cloning without authentication"
fi

# Check if INSTALL_DIR is set
if [ -z "${INSTALL_DIR}" ]; then
    echo -e "${GREEN}INSTALL_DIR is not set, defaulting to 'Servers/unturned'"
    INSTALL_DIR="Servers/unturned"
fi

# Remove temp dir if exists
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

# Read egg-config.json file in CONFIG_SET and delete all paths specified in Delete array
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

# Apply egg-config.json
if [ -f "${TEMP_DIR}/egg-config.json" ]; then
    echo -e "${GREEN}Copying ${TEMP_DIR}/egg-config.json to ${INSTALL_DIR}/egg-config.json"
    cp ${TEMP_DIR}/egg-config.json ${INSTALL_DIR}/egg-config.json
else
    echo -e "${GREEN}${TEMP_DIR}/egg-config.json not found, skipping"
fi

# Collect override paths for config merging
CONFIG_MERGE_PATHS=("${INSTALL_DIR}/Config.json")

if [ -n "${CONFIG_OVERRIDES}" ]; then
    CONFIG_OVERRIDE_PATH="${TEMP_DIR}/Overrides/Config/${CONFIG_OVERRIDES}.json"
    [ -f "$CONFIG_OVERRIDE_PATH" ] && CONFIG_MERGE_PATHS+=("$CONFIG_OVERRIDE_PATH")
fi

GAMEPLAY_OVERRIDE_PATH="${TEMP_DIR}/Overrides/Gameplay/${GAMEPLAY_OVERRIDES}.json"
[ -f "$GAMEPLAY_OVERRIDE_PATH" ] && CONFIG_MERGE_PATHS+=("$GAMEPLAY_OVERRIDE_PATH")

LOOTMX_PATH="${TEMP_DIR}/LootMx/${LOOTMX}.json"
if [ "${LOOTMX}" != "1x" ] && [ -f "$LOOTMX_PATH" ]; then
    CONFIG_MERGE_PATHS+=("$LOOTMX_PATH")
fi

# Merge all config overrides at once if any overrides exist
if [ ${#CONFIG_MERGE_PATHS[@]} -gt 1 ]; then
    echo -e "${GREEN}Merging config overrides: ${CONFIG_MERGE_PATHS[*]}"
    # Debug: print the combined input to check for missing/invalid JSON
    jq -s '.' "${CONFIG_MERGE_PATHS[@]}" > "${INSTALL_DIR}/Config.debug.json"
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}jq failed to parse one or more config files. Check ${INSTALL_DIR}/Config.debug.json for input."
        exit 1
    fi
    jq -s '
      def deepmerge(a; b):
        if (a == null) then b
        elif (b == null) then a
        elif ( (a | type) == "object" and (b | type) == "object" ) then
          reduce (a | keys_unsorted[]) as $key
            ( {}; . + { ($key): if ($key | in(b)) then deepmerge(a[$key]; b[$key]) else a[$key] end } )
          + reduce (b | keys_unsorted[]) as $key
            ( {}; if ($key | in(a)) then . else . + { ($key): b[$key] } end )
        else b end;
      reduce .[] as $item ({}; deepmerge(.; $item))
    ' "${CONFIG_MERGE_PATHS[@]}" > "${INSTALL_DIR}/Config.tmp.json"
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}jq deep merge failed. Check ${INSTALL_DIR}/Config.debug.json for input."
        exit 1
    fi
    mv "${INSTALL_DIR}/Config.tmp.json" "${INSTALL_DIR}/Config.json"
else
    echo -e "${GREEN}No config overrides to merge."
fi

# Apply workshop overrides if set
WORKSHOP_OVERRIDE_PATH="${TEMP_DIR}/Overrides/Workshop/${WORKSHOP}.json"
if [ -n "${WORKSHOP}" ]; then
    echo -e "${GREEN}Workshop config overrides found, applying workshop overrides"
    if [ -f "$WORKSHOP_OVERRIDE_PATH" ]; then
        echo -e "${GREEN}Overriding values in ${INSTALL_DIR}/WorkshopDownloadConfig.json with $WORKSHOP_OVERRIDE_PATH"
        jq '. * input' ${INSTALL_DIR}/WorkshopDownloadConfig.json "$WORKSHOP_OVERRIDE_PATH" > ${INSTALL_DIR}/WorkshopDownloadConfig.tmp.json && mv ${INSTALL_DIR}/WorkshopDownloadConfig.tmp.json ${INSTALL_DIR}/WorkshopDownloadConfig.json
    else
        echo -e "${GREEN}$WORKSHOP_OVERRIDE_PATH not found, skipping workshop overrides"
    fi
fi

# Move Rocket directory contents if set
ROCKET_SOURCE_PATH="${TEMP_DIR}/Rocket/${ROCKET_DIR}"
ROCKET_DEST_PATH="${INSTALL_DIR}/Rocket/"
if [ -n "${ROCKET_DIR}" ]; then
    echo -e "${GREEN}Moving contents of $ROCKET_SOURCE_PATH to $ROCKET_DEST_PATH"
    cp -r $ROCKET_SOURCE_PATH/* $ROCKET_DEST_PATH
fi

# Install Kits plugin/configs if enabled
KITS_DLL_PATH="${TEMP_DIR}/Kits/Kits.dll"
KITS_SOURCE_PATH="${TEMP_DIR}/Kits/Kits/"
KITS_DEST_PATH="${INSTALL_DIR}/Rocket/Plugins/Kits"
if [ "${KITS}" == "1" ]; then
    echo -e "${GREEN}Kits are enabled"
    cp $KITS_DLL_PATH ${INSTALL_DIR}/Rocket/Plugins
    mkdir -p $KITS_DEST_PATH
    cp $KITS_SOURCE_PATH* $KITS_DEST_PATH
else
    echo -e "${GREEN}Kits are disabled, skipping installation"
fi

# Clean up temporary directory
echo -e "${GREEN}Cleaning up: removing temporary directory ${TEMP_DIR}"
rm -rf ${TEMP_DIR}

# Log end of script
echo -e "${GREEN}Repository clone script completed"