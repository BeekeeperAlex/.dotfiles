FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN touch /.dockerenv

ENV USERNAME=chev
ENV USER_UID=1000
ENV USER_GID=1000

RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
	apt-get update -y && \
	apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		file \
		git \
		procps \
		sudo \
		tzdata \
		unzip \
		zsh && \
	rm -rf /var/lib/apt/lists/* && \
	dpkg-reconfigure --frontend noninteractive tzdata

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
	useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} && \
	echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} && \
	chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}

ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

COPY --chown=${USERNAME} ./ ${HOME}/.dotfiles

WORKDIR ${HOME}/.dotfiles
RUN ./install.sh

ENV SHELL=/usr/bin/zsh
ENV TERM=xterm-256color

CMD ["zsh", "-l"]
