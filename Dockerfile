ARG BASE_IMAGE=quay.io/jupyter/scipy-notebook:2024-07-29

FROM ${BASE_IMAGE}

USER root
WORKDIR /opt/

# Install OS Dependencies
RUN apt-get update -y \
 && apt-get install -y \
    cmake \
    gcc \
    g++ \
    gfortran \
    openmpi-bin \
    libopenmpi-dev \
    lammps \
    openkim-models \
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

# # Install GROMACS
# RUN wget https://ftp.gromacs.org/gromacs/gromacs-2024.3.tar.gz \
#  && tar xfz gromacs-2024.3.tar.gz \
#  && rm gromacs-2024.3.tar.gz \
#  && cd gromacs-2024.3 \
#  && mkdir build \
#  && cd build \
#  && cmake .. -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON \
#  && make \
#  && make install \
#  && source /usr/local/gromacs/bin/GMXRC

# Install AMS
# RUN wget https://downloads.scm.com/Downloads/download2024/bin/ams2024.102.pc64_linux.openmpi.bin.tgz
# COPY ams2024.102.pc64_linux.openmpi.bin.tgz ams2024.102.pc64_linux.openmpi.bin.tgz
# RUN tar -xf ams2024.102.pc64_linux.openmpi.bin.tgz

# Install Quantum Espresso
COPY qe-7.3.1-ReleasePack.tar.gz /opt/
RUN tar -xvf qe-7.3.1-ReleasePack.tar.gz \
 && rm qe-7.3.1-ReleasePack.tar.gz

WORKDIR /opt/qe-7.3.1

# Compile Quantum Espresso source code
RUN ./configure \
 && make all

# Set QE environment variables
RUN sed -i 's|TMP_DIR=\$PREFIX/tempdir|TMP_DIR=/tmp|' environment_variables \
 && sed -i 's|# PARA_PREFIX="mpirun -np 4"|PARA_PREFIX="mpirun -np 4"|' environment_variables

# Ensure jovyan/notebook user owns everything under the QE directory
RUN chown -R 1000:100 /opt/qe-7.3.1

# Switch back to notebook user
USER $NB_USER
WORKDIR /home/${NB_USER}

# Install Jupyter Desktop
RUN mamba install -y -q -c manics \
    websockify

# Install ovito
RUN mamba install -y -q -n base \
    ovito

# Install jupyter desktop proxy
RUN pip install jupyter-remote-desktop-proxy

# Add QE binaries to jovyan's path
ENV PATH=/opt/qe-7.3.1/bin:$PATH
