FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
    && apt-get install -y build-essential \
    && apt-get install -y wget unzip libxml2-dev librhash-dev software-properties-common pkg-config libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libassimp-dev git

RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update -y && \
    apt install g++-9 -y && \
    g++-9 --version

WORKDIR /root
# Install miniconda
ENV CONDA_DIR /root/anaconda3/
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /root/miniconda.sh && \
    /bin/bash /root/miniconda.sh -b -p $CONDA_DIR && rm /root/miniconda.sh

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

RUN mkdir /root/neat
WORKDIR /root/neat

RUN conda create -y -n neat python=3.8
ENV CONDA_DEFAULT_ENV neat

RUN conda install -n neat -y ncurses=6.3 -c conda-forge
RUN conda install -y cudnn=8.2.1 cudatoolkit-dev=11.3.1 cudatoolkit=11.3.1 -c nvidia -c conda-forge
RUN conda install -n neat -y configargparse=1.4 astunparse=1.6.3 numpy=1.21.2 ninja=1.10.2 pyyaml mkl=2022.0.1 mkl-include=2022.0.1 setuptools=58.0.4 cmake=3.19.6 cffi=1.15.0 typing_extensions=4.1.1 future=0.18.2 six=1.16.0 requests=2.27.1 dataclasses=0.8
RUN conda install -n neat -y magma-cuda110=2.5.2 -c pytorch
RUN conda install -n neat -y -c conda-forge coin-or-cbc=2.10.5 glog=0.5.0 gflags=2.2.2 protobuf=3.13.0.1 freeimage=3.17 tensorboard=2.8.0
RUN wget https://download.pytorch.org/libtorch/cu113/libtorch-cxx11-abi-shared-with-deps-1.11.0%2Bcu113.zip -O  libtorch.zip && \
    unzip libtorch.zip -d . && rm libtorch.zip && \
    cp -rv libtorch/ $CONDA_DIR/envs/neat/lib/python3.8/site-packages/torch/

RUN ln -sf /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /root/anaconda3/envs/neat/bin/../lib/libstdc++.so.6

COPY ./ ./
RUN mkdir -p ~/.ssh
RUN echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
RUN git submodule update --init --recursive --jobs 1 --depth 1

RUN mkdir build
WORKDIR /root/neat/build
RUN bash -c "source activate neat && \
    conda env config vars set CC=gcc-9 && \
    conda env config vars set CXX=g++-9 && \
    conda env config vars set CUDAHOSTCXX=g++-9 && \
    conda env config vars set CONDA=/root/anaconda3/envs/neat && \
    conda env config vars set LD_LIBRARY_PATH=/root/anaconda3/envs/neat/lib"

ENV CC gcc-9
ENV CXX g++-9
ENV CUDAHOSTCXX g++-9
ENV CONDA=/root/anaconda3/envs/neat
ENV LD_LIBRARY_PATH=/root/anaconda3/envs/neat/lib

ENV CUDA_ARCH="6.1 7.0 7.5 8.0 8.6+PTX"

RUN bash -c "conda init"
RUN echo "conda activate neat" >> ~/.bashrc
RUN conda run -n neat cmake -DCMAKE_PREFIX_PATH="${CONDA}/lib/python3.8/site-packages/torch/;${CONDA}" -DTorch_DIR="/root/neat/External/libtorch/share/cmake/Torch/" -DSAIGA_CUDA_ARCH="${CUDA_ARCH}" -DTORCH_CUDA_ARCH_LIST="${CUDA_ARCH}" ..
RUN make -j4

WORKDIR /root/neat