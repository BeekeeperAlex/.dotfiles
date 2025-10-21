FROM alpine:latest

# Most of the time a user will be using a capable terminal emulator so we set a reasonable default.
ENV TERM=xterm-256color

# Copy only nvim configuratoin.
COPY ./nvim /root/.config/nvim

# Install the packages required for Neovim and plugins.
RUN apk update && apk upgrade && apk add --no-cache \
	bash \
	autoconf \
	automake \
	build-base \
	cmake \
	coreutils \
	curl \
	fd \
	gperf \
	gettext-dev \
	git \
	lazygit \
	libtool \
	lua \
	ncurses-terminfo-base \
	ninja \
	nodejs \
	npm \
	pkgconf \
	python3 \
	py3-pip \
	ripgrep \
	unzip

# Build and install the latest Neovim from source (LazyVim requires >= 0.11.2).
RUN git clone --depth=1 https://github.com/neovim/neovim.git /tmp/neovim \
	&& cd /tmp/neovim \
	&& cmake -S cmake.deps -B .deps -G Ninja \
	&& cmake --build .deps \
	&& cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BUNDLED=ON \
	&& cmake --build build \
	&& cmake --install build \
	&& rm -rf /tmp/neovim

ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"

# Update Neovim plugins.
RUN nvim --headless "+set nomore" "+Lazy! sync" "+MasonUpdate" "+TSUpdateSync" +qa

# Setup default entrypoint.
WORKDIR /root
ENTRYPOINT ["nvim"]
CMD []
