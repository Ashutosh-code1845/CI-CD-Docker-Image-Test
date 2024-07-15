#!/bin/bash

EXISTING_LOG_FILE="/home/outletmanager/.outlet-data/vision-app/logs/dependency_status.log"
LOG_FILE="/home/outletmanager/.outlet-data/vision-app/logs/dependency_status_temp.log"

START_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo -n "{\"timestamp\": \"$START_TIMESTAMP\",\"outlet_code\": \"$(cat /home/outletmanager/.outlet-data/main.properties | grep "consumer.topic" | awk -F'=' '{print $2}')\", \"log_steps\": [" > "$LOG_FILE"

#detecting first step log
first_step=true
error_command=""
exit_code=""


log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local step_message=$1

    if [ "$first_step" = true ]; then
        first_step=false
    else
        echo -n "," >> "$LOG_FILE"
    fi

    echo -n "{\"timestamp\": \"$timestamp\", \"message\": \"$step_message\"}" >> "$LOG_FILE"
}

handle_error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local error_command="$BASH_COMMAND"
    local command_output=$(eval "$error_command" 2>&1)
    local formatted_command_output=$(printf "%s" "$command_output" | tr '\n' ' ')
    echo "],\"error_log\":{\"timestamp\": \"$timestamp\", \"error_message\": \"$formatted_command_output\",\"error_command\": \"$error_command\"}}" >> "$LOG_FILE"
    cat "$LOG_FILE" >> "$EXISTING_LOG_FILE"
    rm "$LOG_FILE"
    echo "Error Occured"
}

trap 'handle_error' ERR

#Starting main dependency flow
# apt-get checking
if ! which apt-get >/dev/null; then
  apt-get update
  apt-get install apt
  log "apt-get installed successfully."
else
  log "apt-get found."
fi

# deadsnakes PPA checking
ppa_name="deadsnakes-ubuntu-ppa-jammy" # Issue: deadsnakes-ubuntu-ppa-jammy.list name (in both machines)
ppa_file="/etc/apt/sources.list.d/${ppa_name}.list"

if ! [ -f "$ppa_file" ]; then
  yes "" | add-apt-repository ppa:deadsnakes/ppa
  log "PPA '${ppa_name}' installed successfully"
else
  log "PPA '${ppa_name}' is already installed."
fi

# Python 3.9 checking ; Is this required?
if ! python3.9 --version 2>&1 | grep -q "Python 3.9"; then
  apt-get install -y python3.9
  log "Python 3.9 installed successfully"
else
  log "Python 3.9 is installed."
fi


apt-get install python3.9-venv python3.9-dev -y

# Checking if the venv is already present in the system [Multiple runs of dependencies.sh]

python_version="3.9"  # Specify the desired Python version
venv_path="/home/outletmanager/vision-face"  # Specify the path to your virtual environment directory

if ! [ -d "$venv_path" ] || ! [ -x "$venv_path/bin/python$python_version" ]; then
  python3.9 -m venv /home/outletmanager/vision-face
  log "The virtual environment with Python $python_version is now created."
else
  log "The virtual environment with Python $python_version is already present."
fi

# Activating virtual environment
source /home/outletmanager/vision-face/bin/activate

log "venv activated"

pip install wheel --timeout 600
log "Wheel Installed"

pip install --upgrade setuptools --timeout 600
log "Setup Tools Installed"

# build-essential checking (gcc fatal error might be ignored : issue)
if ! command -v gcc >/dev/null; then
  apt-get install build-essential -y
  log "Build essentials (including gcc) is installed."
else
  log "Build essentials (including gcc) is already installed."
fi

# libx11-dev checking
libx11_file_path="/usr/include/X11/Xlib.h"  

if ! [ -f "$libx11_file_path" ]; then
   apt-get install libx11-dev -y
   log "libx11-dev is now installed."
else
  log "libx11-dev is already installed."
fi

# libatlas-base-dev checking
libtlas_lib_file="/usr/lib/libatlas.so"

if ! [ -f "$libtlas_lib_file" ]; then
  apt-get install libatlas-base-dev -y
  log "libatlas-base-dev is now installed."
else
  log "libatlas-base-dev is already installed."
fi

# libgtk-3-dev checking
libgtk_lib_file="/usr/lib/x86_64-linux-gnu/libgtk-3.so"

if ! [ -f "$libgtk_lib_file" ]; then
  apt-get install libgtk-3-dev -y
  log "libgtk-3-dev is now installed."
else
  log "libgtk-3-dev is already installed."
fi

# libboost-python-dev checking
libboost_lib_file="/usr/lib/libboost_python.so"

if ! [ -f "$libboost_lib_file" ]; then
  apt-get install libboost-python-dev -y
  log "libboost-python-dev is now installed."
else
  log "libboost-python-dev is already installed."
fi

# CMake alternative (with version check)
cmake_required_version="3.26.0"

cmake_version=$(cmake --version | awk 'NR==1 {print $3}')

if [ "$cmake_version" != "$cmake_required_version" ]; then
  pip install cmake==$cmake_required_version --timeout 600
  log "CMake version $cmake_required_version is now installed."
else
  log "CMake version $cmake_required_version is already installed."
fi

# Make alternative (with version check)
make_required_version="4.3"

make_version=$(make --version | awk 'NR==1 {print $3}')
log "Make version found: $make_version"
if [ "$make_version" != "$make_required_version" ]; then
  apt-get install make
  log "Make version $make_required_version is now installed."
else
  
  log "Make version $make_required_version is already installed."
fi

# git checking
if ! command -v git >/dev/null; then
  apt-get install git -y
  log "Git is now installed."
else
  log "Git is already installed."
fi

#TODO [git-clone dlib from self hosted repo]
# directory="/home/outletmanager/.outlet-data/vision-app/vision/"
directory="/home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision"

# Check if the directory exists
if ! [ -d "$directory" ]; then
    log "Directory $directory does not exist, Creating... "
    cd /home/outletmanager/.outlet-data/temp_download_folder/vision-app/ && git clone https://gitlab.com/Box8/vision.git
else
    log "Directory $directory already exists."
fi

cd /home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/dlib 

# Check if the directory exists
if ! [ -d "/home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/dlib/build" ]; then
    log "Directory /home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/dlib/build does not exist, Creating..."
    mkdir build 
else
    log "Directory /home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/dlib/build exists."
fi

cd /home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/dlib/build
cmake .. && make -j8

cd /home/outletmanager/.outlet-data/temp_download_folder/vision-app

pip install -r requirements.txt --timeout 600
log "Installed libraries in requirements.txt"

if ! command -v protoc >/dev/null; then
  apt-get install protobuf-compiler -y
  log "protobuf-compiler is now installed."
else
  log "protobuf-compiler is already installed."
fi

protobuf_required_version="3.19.6"

protobuf_version=$(protoc --version | awk 'NR==1 {print $2}')

if [ "$protobuf_version" != "$protobuf_required_version" ]; then
  pip install protobuf==$protobuf_required_version --timeout 600
  log "Protobuf (python) version $protobuf_required_version is now installed."
else
  
  log "Protobuf (python) version $protobuf_required_version is already installed."
fi

#TODO [git-clone tensorflow/models from self hosted repo]

# OD Python lib
cd /home/outletmanager/.outlet-data/temp_download_folder/vision-app/vision/models/research
protoc object_detection/protos/*.proto --python_out=.
# cp object_detection/packages/tf2/setup.py setup.py
python -m pip install . --timeout 600
pip uninstall -y opencv-python-headless

pip uninstall -y opencv-python
pip install opencv-python==4.4.0.46 --timeout 600
log "Installed opencv-python"

# Failsafe
# pip install pybind11==2.6.2

#  - Remove 'pycocotools' from the required_packages list.
#  + Add 'opencv-python-headless==4.4.0.44' to the required_packages list

# If everything worked fine then copy content of temp_download to main folder of vision-app
log "Copying vision-app folder to /home/outletmanager/.outlet-data/"
cp -r "/home/outletmanager/.outlet-data/temp_download_folder/vision-app/" "/home/outletmanager/.outlet-data/"
log "copied temp_download directory content to vision-app folder successfully"


apt install jshon
log "jshon installed successfully"
# Read version from version file
version=$(cat /home/outletmanager/.outlet-data/temp_download_folder/vision-app/version | awk -F'=' '{print $2}')
# Read access_token from sqlite
access_token=$(sqlite3 /home/outletmanager/.outlet-data/details.db "select value from outlet_info where name='access_token'";)
# request to update current version
result=$(curl -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" --data "{\"vision_app_version\":\"$version\"}" https:/outletservice.box8.co.in/group_account/update_version)
code=$(jshon -e code -u <<< "$result")
if [ [$code==200] ]; then
    log "vision-app current version updated successfully on outlet-service"
else
    log "vision-app current version didn't update successfully on outlet-service"
fi


touch /home/outletmanager/.outlet-data/vision-app/logs/frame.log
touch /home/outletmanager/.outlet-data/vision-app/logs/functional.log
log "Frame and Functional log files created"

# Check if the directory exists
if ! [ -d "/home/outletmanager/.outlet-data/vision-app/logs/frames" ]; then
    log "Frames directory does not exist. Creating it."
    mkdir /home/outletmanager/.outlet-data/vision-app/logs/frames
else
    log "Frames directory exists."
fi


#Starting vision attendance service
serviceName="vision_attendance.service"
cp /home/outletmanager/.outlet-data/vision-app/vision_attendance.service /etc/systemd/system/

if systemctl list-units --full -all | grep -Fq "$serviceName";then
    systemctl daemon-reload
    systemctl restart "$serviceName"
    log "$serviceName alreay installed"
else
    systemctl enable "$serviceName"
    systemctl start "$serviceName"
    log "$serviceName is now present."
fi

#Starting frame upload service
serviceName="frame_upload.service"
cp /home/outletmanager/.outlet-data/vision-app/frame_upload.service /etc/systemd/system/

if systemctl list-units --full -all | grep -Fq "$serviceName";then
    systemctl daemon-reload
    systemctl restart "$serviceName"
    log "$serviceName alreay installed"
else
    systemctl enable "$serviceName"
    systemctl start "$serviceName"
    log "$serviceName is now present."
fi

serviceName="frame_upload.timer"
cp /home/outletmanager/.outlet-data/vision-app/frame_upload.timer /etc/systemd/system/

if systemctl list-units --full -all | grep -Fq "$serviceName";then
    systemctl daemon-reload
    systemctl restart "$serviceName"
    log "$serviceName alreay installed"
else
    systemctl enable "$serviceName"
    systemctl start "$serviceName"
    log "$serviceName is now present."
fi

## Starting camera config service

serviceName="camera_config.service"
cp /home/outletmanager/.outlet-data/vision-app/camera_config.service /etc/systemd/system/

if systemctl list-units --full -all | grep -Fq "$serviceName";then
    systemctl daemon-reload
    systemctl restart "$serviceName"
    log "$serviceName alreay installed"
else
    systemctl enable "$serviceName"
    systemctl start "$serviceName"
    log "$serviceName is now present."
fi


serviceName="camera_config.timer"
cp /home/outletmanager/.outlet-data/vision-app/camera_config.timer /etc/systemd/system/

if systemctl list-units --full -all | grep -Fq "$serviceName";then
    systemctl daemon-reload
    systemctl restart "$serviceName"
    log "$serviceName alreay installed"
else
    systemctl enable "$serviceName"
    systemctl start "$serviceName"
    log "$serviceName is now present."
fi


# Update VISION_INSTALLATION_FLAG value
sqlite_db_file="/home/outletmanager/.outlet-data/details.db"
update_query="INSERT OR REPLACE INTO outlet_info (name, value) VALUES ('VISION_INSTALLATION_FLAG', 'false');"
# Use sqlite3 to execute the query and store the result in a variable
result=$(sqlite3 "$sqlite_db_file" "$update_query")

log "Installation completion Flag Update"

log "END_MARKER"

# Close logs
echo "]}" >> "$LOG_FILE"
# Appending new logs to the existing log file
cat "$LOG_FILE" >> "$EXISTING_LOG_FILE"
rm $LOG_FILE

echo "END_MARKER"