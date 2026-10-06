# Use the official TensorFlow GPU image with Jupyter pre-installed
FROM tensorflow/tensorflow:latest-gpu-jupyter

# Set directory inside the container
WORKDIR /tf

# Copy ISBI 2015 dataset
COPY data/ISBI2015/ /tf/data/ISBI2015/

# Install additional system dependencies
USER root
RUN apt-get update && apt-get install -y \
    git \
    graphviz \
    libgl1-mesa-glx \
    libglib2.0-0 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh

COPY runpod.pub /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config

# Upgrade pip
RUN pip install --upgrade pip

# Install PyTorch built for CUDA 12.8. Blackwell GPUs (RTX PRO 6000, RTX 50xx; compute capability sm_120)
# need PyTorch >= 2.7 with CUDA >= 12.8; the cu121 wheels stop at sm_90 and fail with
# 'no kernel image is available for execution on the device'. cu128 also runs on Ampere/Ada/Hopper.
RUN pip install "torch>=2.7" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 && \
    pip install timm && \
    python -c "import torch; v = tuple(int(x) for x in torch.version.cuda.split('.')[:2]); assert v >= (12, 8), torch.version.cuda; print(torch.__version__, torch.version.cuda)"

# Install Data Science & Visualization libraries
RUN pip install \
    matplotlib \
    seaborn \
    scikit-learn \
    pandas \
    tqdm \
    jupyterlab

RUN pip install ultralytics
RUN pip install opencv-python-headless
RUN pip install pydicom
RUN pip install pingouin

# Expose ports
EXPOSE 8888
EXPOSE 22

# Copy notebooks
COPY notebooks/ /tf/notebooks

CMD ["bash", "-c", "service ssh start && source /etc/bash.bashrc && jupyter lab \
    --notebook-dir=/tf \
    --ip=0.0.0.0 \
    --no-browser \
    --allow-root \
    --ServerApp.token='' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*' \
    --ServerApp.allow_remote_access=True \
    --ServerApp.disable_check_xsrf=True \
    --ServerApp.tornado_settings=\"{'headers':{'Content-Security-Policy':'frame-ancestors * self'}}\""]
