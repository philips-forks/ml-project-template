FROM condaforge/miniforge3:4.12.0-0
ENV PYTHONUNBUFFERED 1


# ---------------------------------- Initializization -----------------------------------
ARG userpwd=passwd
RUN sh -c "echo root:$userpwd | chpasswd" \
    && mkdir -p /root/.ssh \
    && mkdir -p /root/.jupyter


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
COPY environment.yaml /root/conda_environment.yaml
COPY requirements.txt /root/requirements.txt
RUN conda update -n base conda
RUN conda env update -n base -f /root/conda_environment.yaml
RUN xargs -L 1 pip install --no-cache-dir < /root/requirements.txt
 

# ------------------- Configure Jupyter and Tensorboard individually --------------------
COPY .jupyter_password set_jupyter_password.py /root/.jupyter/
RUN conda install -y jupyterlab ipywidgets tensorboard \
    && python /root/.jupyter/set_jupyter_password.py /root

RUN echo "#!/bin/sh" > ~/init.sh \
    && echo "/opt/conda/bin/jupyter lab --allow-root --no-browser &" >> ~/init.sh \
    && echo "/opt/conda/bin/tensorboard --logdir=\$TB_DIR --bind_all" >> ~/init.sh \
    && chmod +x ~/init.sh

RUN conda clean --all --yes


# ------------------------------------ Miscellaneous ------------------------------------
ENV TB_DIR=/ws/experiments
WORKDIR /code
EXPOSE 8888
EXPOSE 6006
EXPOSE 22

CMD ~/init.sh
