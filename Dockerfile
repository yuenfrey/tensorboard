# Stage 1: Build Environment
FROM ubuntu:latest AS builder

# Install environment dependencies
RUN apt update && apt install -y wget unzip python3 python3-pip python3-dev python-is-python3 default-jdk nodejs npm
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Setup build environment
ENV BAZEL_VERSION='6.5.0'
ENV BAZEL_SHA256SUM='a40ac69263440761199fcb8da47ad4e3f328cbe79ffbf4ecc14e5ba252857307'
ENV BUILDTOOLS_VERSION='3.0.0'
ENV BUILDIFIER_SHA256SUM='e92a6793c7134c5431c58fbc34700664f101e5c9b1c1fcd93b97978e8b7f88db'
ENV BUILDOZER_SHA256SUM='3d58a0b6972e4535718cdd6c12778170ea7382de7c75bc3728f5719437ffb84d'
ENV TENSORFLOW_VERSION='tf-nightly'

RUN mkdir /tensorboard
WORKDIR /tensorboard

# Setup Bazel
COPY ./ci /tensorboard/ci
RUN ci/download_bazel.sh "${BAZEL_VERSION}" "${BAZEL_SHA256SUM}" ~/bazel
RUN mv ~/bazel /usr/local/bin/bazel && chmod +x /usr/local/bin/bazel && cp ./ci/bazelrc ~/.bazelrc
RUN npm i -g @bazel/ibazel

# Install python dependencies
COPY ./tensorboard/pip_package /tensorboard/tensorboard/pip_package
RUN pip install -r ./tensorboard/pip_package/requirements.txt -r ./tensorboard/pip_package/requirements_dev.txt "$TENSORFLOW_VERSION"

# Get the code
COPY . /tensorboard

# Build the pip package
# 1. Build the builder target
RUN bazel build //tensorboard/pip_package:build_pip_package
# 2. Run the builder to generate the wheel file in /tmp/pip_pkg
RUN ./bazel-bin/tensorboard/pip_package/build_pip_package /tmp/pip_pkg

# Stage 2: Runtime Environment
FROM python:3.10-slim

WORKDIR /app

# Copy the built wheel from the builder stage
COPY --from=builder /tmp/pip_pkg/*.whl /tmp/

# Install the package
RUN pip install --no-cache-dir /tmp/*.whl && \
    rm -rf /tmp/*.whl

# Default command
EXPOSE 6006
ENTRYPOINT ["tensorboard"]
CMD ["--logdir", "/tensorboard_logs", "--bind_all"]
