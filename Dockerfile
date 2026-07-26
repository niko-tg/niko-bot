# 
# Нужные файлы и директории
# --=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=
# instances.enabled - Исходники приложения
# entrypoint - Точка входа
# --=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=
#

FROM tarantool/tarantool:3.7

ENV APP_INSTANCE_SRC="/opt/tarantool/instances.enabled"
ENV INSTANCE_NAME="tnt-niko-bot"
ENV BOT_INSTANCE_SRC="/opt/tarantool/instances.enabled/${INSTANCE_NAME}"

RUN set -x \
  # Because their servers are not responding
  && rm /etc/apt/sources.list.d/tarantool.list \
  # Installing tools/libs
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
    luarocks \
    unzip \
    git \
    make \
    cmake \
    gcc \
    libssl-dev \
    liblua5.1-0-dev \
    libcairo2-dev \
  #
  # Cleanup
  #
  && apt autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR ${BOT_INSTANCE_SRC}

COPY entrypoint /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

EXPOSE 9091

ENTRYPOINT ["/usr/local/bin/entrypoint"]
