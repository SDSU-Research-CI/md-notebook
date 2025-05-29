ARG BASE_IMAGE=quay.io/jupyter/scipy-notebook:2024-07-29

# Stage 1: build GROMACS
FROM nvidia/cuda:12.4.0-devel-ubuntu22.04 AS gromacs-builder

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    gcc \
    g++ \
    gfortran \
    openmpi-bin \
    libopenmpi-dev \
    wget \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/

# Install newer CMake
RUN wget https://github.com/Kitware/CMake/releases/download/v4.0.2/cmake-4.0.2-linux-x86_64.tar.gz \
 && tar -xvf cmake-4.0.2-linux-x86_64.tar.gz \
 && rm cmake-4.0.2-linux-x86_64.tar.gz \
 && mv cmake-4.0.2-linux-x86_64/bin/cmake /usr/bin/cmake \
 && mv cmake-4.0.2-linux-x86_64/share/cmake-4.0 /usr/share/cmake-4.0 \
 && rm -rf cmake-4.0.2-linux-x86_64/

ENV PATH=/usr/local/cuda-12.4/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH

# Download GROMACS
RUN wget https://ftp.gromacs.org/gromacs/gromacs-2025.1.tar.gz \
 && tar xfz gromacs-2025.1.tar.gz \
 && rm gromacs-2025.1.tar.gz

# Install GROMACS
RUN cd gromacs-2025.1 \
 && mkdir build \
 && cd build \
 && cmake .. \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DREGRESSIONTEST_DOWNLOAD=ON \
    -DGMX_GPU=CUDA \
    -DGMX_SIMD=AVX2_256 \
    -DGMX_OPENMP=ON \
    -DGMX_USE_RDTSCP=ON \
    -DGMX_MPI=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.4 \
    -DCUDAToolkit_ROOT=/usr/local/cuda-12.4 \
    -DGMX_CUDA_NVCC_FLAGS="-allow-unsupported-compiler" \
 && make -j4 \
 && make install
# RUN source /usr/local/gromacs/bin/GMXRC

# Stage 2: runtime image
FROM ${BASE_IMAGE} AS notebook-image

USER root
WORKDIR /opt/

# Install OS Dependencies
RUN apt-get update -y \
 && apt-get install -y \
    cmake \
    gcc \
    g++ \
    gfortran \
    software-properties-common \
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

# Install CUDA, without drivers
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin \
 && mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 \
 && apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub \
 && add-apt-repository -y "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" \
 && apt update -y \
 && apt-get install -y --no-install-recommends \
    cuda-cudart-12-4 \
    libcublas-12-4 \
    libcufft-12-4 \
    libcurand-12-4 \
    libcusolver-12-4 \
    libcusparse-12-4 \
    libnpp-12-4 \
    libnvjpeg-12-4 \
 && rm -rf /var/lib/apt/lists/*

# Copy GROMACS from build stage
COPY --from=gromacs-builder /usr/local/gromacs /usr/local/gromacs

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

# Copy lammps examples 
RUN mkdir -p /opt/lammps/ \
 && cp -r /usr/share/lammps/examples /opt/lammps/ \
 && chown -R 1000:100 /opt/lammps

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
