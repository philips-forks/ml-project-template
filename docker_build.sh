#!/bin/bash
set -e

echo "------------------------ Hi, let's set up your project! ------------------------"

# ---------------------------- Prompts to define variables  -----------------------------
curdir=${PWD##*/}
read -r -p "Set up Docker image name[:tag] [$curdir]: " docker_image_name
docker_image_name=${docker_image_name:-$curdir}

read -s -p "Set up SSH password: " ssh_password
echo ""

read -s -p "Set up password for Jupyter: " password
echo ""

echo $password > .jupyter_password
echo $ssh_password > .ssh_password
echo $docker_image_name > .docker_image_name
echo "" > .ws_dir
echo "" > .tb_dir


# ------------------------------------ Build docker -------------------------------------
docker build -t $docker_image_name \
    --build-arg username=$(whoami) \
    --build-arg groupname=$(id -g -n) \
    --build-arg uid=$(id -u) \
    --build-arg gid=$(id -g) \
    --build-arg userpwd=$ssh_password \
    --build-arg http_proxy=$http_proxy \
    --build-arg https_proxy=$https_proxy \
    --build-arg HTTP_PROXY=$HTTP_PROXY \
    --build-arg HTTPS_PROXY=$HTTPS_PROXY \
    .


# ----- Install user packages from ./src to the container and submodules from ./libs ----
docker run -dt -v ${PWD}:/code --name tmp_container $docker_image_name
for lib in $(ls ./libs)
    do
        if test -f /code/libs/$lib/setup.py; then
            echo "Installing $lib"
            docker exec tmp_container pip install -e /code/libs/$lib/.
        else 
            echo "$lib does not have setup.py file to install."
        fi
    done
docker exec tmp_container pip install -e /code/.
docker stop tmp_container
docker commit --change='CMD ~/init.sh' tmp_container $docker_image_name
docker rm tmp_container &> /dev/null


echo "------------------ Build successfully finished! --------------------------------"
echo "------------------ Start the container: bash docker_start.sh -------------------"
