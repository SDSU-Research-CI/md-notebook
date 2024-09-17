ARG BASE_IMAGE=quay.io/jupyter/minimal-notebook:2024-07-29

FROM ${BASE_IMAGE}

USER root
WORKDIR /opt/

# Install OS Dependencies
RUN apt-get update -y \
 && apt-get install -y \
    cmake \
    gcc \
    g++ \
    openmpi-bin \
    vim \
    dbus-x11 \
    xfce4 \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xorg \
    xubuntu-icon-theme \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
&& apt clean \
&& rm -rf /var/lib/apt/lists/* \
&& fix-permissions "${CONDA_DIR}" \
&& fix-permissions "/home/${NB_USER}"

# Install GROMACS
RUN wget https://ftp.gromacs.org/gromacs/gromacs-2024.3.tar.gz \
 && tar xfz gromacs-2024.3.tar.gz \
 && rm gromacs-2024.3.tar.gz \
 && cd gromacs-2024.3 \
 && mkdir build \
 && cd build \
 && cmake .. -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON \
 && make \
 && make install \
 && source /usr/local/gromacs/bin/GMXRC

# Install AMS
RUN wget https://downloads.scm.com/Downloads/download2024/bin/ams2024.102.pc64_linux.openmpi.bin.tgz
RUN cd /opt && tar -xf ams2024.102.pc64_linux.openmpi.bin.tgz

# Switch back to notebook user
USER $NB_USER
WORKDIR /home/${NB_USER}

# Install Jupyter Desktop
RUN /opt/conda/bin/conda install -y -q -c manics websockify
RUN pip install jupyter-remote-desktop-proxy
