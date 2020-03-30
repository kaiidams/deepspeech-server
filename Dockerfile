FROM ubuntu:16.04

ARG DEEPSPEECH_VERSION=0.6.1

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
        ca-certificates \
        build-essential \
	clang-5.0 \
	curl

RUN useradd -c 'ds-srv' -m -d /home/ds -s /bin/bash ds

ENV HOME /home/ds
ENV DS_VER $DEEPSPEECH_VERSION
ENV LD_LIBRARY_PATH $HOME/lib/:$LD_LIBRARY_PATH
ENV LIBRARY_PATH $LD_LIBRARY_PATH
ENV PATH $HOME/.cargo/bin/:$HOME/bin/:$PATH

RUN mkdir /app && chown ds:ds /app

COPY --chown=ds:ds version.json /app/version.json

USER ds

EXPOSE 8080

WORKDIR /home/ds

RUN mkdir -p ${HOME}/lib/ ${HOME}/bin/ ${HOME}/data/models/ ${HOME}/src/ds-srv/

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable

RUN curl https://community-tc.services.mozilla.com/api/index/v1/task/project.deepspeech.deepspeech.native_client.v${DS_VER}.cpu/artifacts/public/native_client.tar.xz -sSL | xz -d | tar -C ${HOME}/lib/ -xf -

RUN curl https://github.com/mozilla/DeepSpeech/releases/download/v${DS_VER}/deepspeech-${DS_VER}-models.tar.gz -sSL | gunzip | tar -C ${HOME}/data/models/ --strip-components 1 -xvf -

COPY Cargo.toml ${HOME}/src/ds-srv/

COPY src ${HOME}/src/ds-srv/src/

# Force stubs required for building, but breaking runtime
RUN cargo install --force --path ${HOME}/src/ds-srv/

ENTRYPOINT ds-srv \
	-vvvv \
	--model $HOME/data/models/output_graph.pbmm \
	--lm $HOME/data/models/lm.binary \
	--trie $HOME/data/models/trie \
	--http_ip ::0 \
	--http_port 8080
