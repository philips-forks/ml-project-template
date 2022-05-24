FROM condaforge/miniforge3
ENV PYTHONUNBUFFERED 1


# ------------------- Add user to avoid root access to attached dirs --------------------
ARG username=user
ARG groupname=user
ARG uid=1000
ARG gid=1000
ARG userpwd=passwd
RUN groupadd -f -g $gid $groupname \
    && useradd -u $uid -g $gid -s /bin/bash -d /home/$username $username \
    && mkdir -p /home/$username/.ssh \
    && echo export PATH=$PATH:/home/$username/.local/bin > /home/$username/.bashrc \
    && echo export http_proxy=$http_proxy >> /home/$username/.bashrc \
    && echo export https_proxy=$https_proxy >> /home/$username/.bashrc \
    && echo export HTTP_PROXY=$HTTP_PROXY >> /home/$username/.bashrc \
    && echo export HTTPS_PROXY=$HTTPS_PROXY >> /home/$username/.bashrc \
    && echo "Acquire::http::Proxy \"$HTTP_PROXY\";" >> /etc/apt/apt.conf.d/10proxy \
    && echo "Acquire::https::Proxy \"$HTTPS_PROXY\";" >> /etc/apt/apt.conf.d/10proxy \
    && chmod a+x /home/$username/.bashrc \
    && chown -R $username:$groupname /home/$username \
    && sh -c "echo $username:$userpwd | chpasswd" \
    && echo export PATH=$PATH > /etc/environment \
    && chmod a+w /opt/conda


# -------------------------- Install essential Linux packages ---------------------------
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    git \
    git-lfs \
    curl \
    wget \
    unzip \
    vim \
    screen \
    tmux \
    python3-opencv \
    openssh-server \
    && mkdir /var/run/sshd \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install


# ----------------------------- Install conda dependencies ------------------------------
COPY Docker/environment.yaml /home/$username/conda_environment.yaml
COPY Docker/requirements.txt /home/$username/requirements.txt
RUN conda update -n base conda \
    && conda env update -n base -f /home/$username/conda_environment.yaml --prune \
    && xargs -L 1 pip install --no-cache-dir < /home/$username/requirements.txt
 

# ------------------- Configure Jupyter and Tensorboard individually --------------------
COPY --chown=$username:$groupname .jupyter_password Docker/set_jupyter_password.py /home/$username/.jupyter/
RUN conda install -y jupyterlab tensorboard \
    && su $username -c "python /home/$username/.jupyter/set_jupyter_password.py $username"

RUN echo "#!/bin/sh" > /init.sh \
    && echo "/opt/conda/bin/jupyter lab --no-browser &" >> /init.sh \
    && echo "/opt/conda/bin/tensorboard --logdir=\$tb_dir --bind_all" >> /init.sh \
    && chmod +x /init.sh

RUN conda clean --all --yes

# ------------------------- Set user and explicit exposed ports -------------------------
USER $username
WORKDIR /code
ENV tb_dir=/ws/experiments
EXPOSE 8888
EXPOSE 6006
EXPOSE 22

CMD /init.sh
