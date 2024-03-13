# LORDSHIPWEATHER.UK docker image (weewx-docker)
# Copied from felddy/weewx and modified to work!
# last updated 24/05/2023 -> weewx-4.10.2
# copied to homepi_weewx on 11/03/2024
# this version last updated 13/03/2024 

#==== INSTALL-WEEWX-STAGE =====

# Can safely use a full debian system (with least restrictions) for the initial-stage, as it is discarded for the final-stage

FROM python:3.10.10-bullseye as install-weewx-stage
# was FROM python:3.10.7-alpine3.15 as install-weewx-stage

# ARG definitions

ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG WEEWX_UID=421
ARG WEEWX_HOME="/home/weewx"
ARG WEEWX_VERSION="4.10.2"
ARG BELCHERTOWN_VERSION="1.3"
ARG ARCHIVE="weewx-${WEEWX_VERSION}.tar.gz"

WORKDIR /tmp
COPY src/hashes requirements.txt ./

# Download extension sources and verify hashes; -nv to give non-verbose output

RUN wget -nv -O "${ARCHIVE}" "https://weewx.com/downloads/released_versions/${ARCHIVE}" && \
    wget -nv -O weewx-interceptor.zip https://github.com/matthewwall/weewx-interceptor/archive/master.zip && \
    wget -nv -O weewx-mqtt.zip https://github.com/matthewwall/weewx-mqtt/archive/master.zip && \
    wget -nv -O weewx-belchertown.tar.gz https://github.com/poblabs/weewx-belchertown/releases/download/weewx-belchertown-${BELCHERTOWN_VERSION}/weewx-belchertown-release-${BELCHERTOWN_VERSION}.tar.gz && \
	sha256sum -c < hashes

# WeeWX setup

RUN addgroup --system --gid ${WEEWX_UID} weewx && \
	adduser --system --uid ${WEEWX_UID} --ingroup weewx weewx && \
	tar --extract --gunzip --directory ${WEEWX_HOME} --strip-components=1 --file "${ARCHIVE}" && \
	chown -R weewx:weewx ${WEEWX_HOME}

# Setup Python and dependencies for Weewx, using pep517 to avoid use of legacy setup warnings

RUN python -m venv /opt/venv && \
	pip install --upgrade pip
COPY ./requirements.txt /usr/src/app
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --use-pep517 -Ur requirements.txt	#--use-pep517 to avoid legacy warning

# Install extensions

WORKDIR ${WEEWX_HOME}
RUN bin/wee_extension --install /tmp/weewx-mqtt.zip && \
	bin/wee_extension --install /tmp/weewx-interceptor.zip && \
	bin/wee_extension --install /tmp/weewx-belchertown.tar.gz
COPY src/entrypoint.sh src/version.txt ./
RUN chmod +x ./entrypoint.sh

# ===== FINAL-STAGE ====

FROM python:3.10.10-slim-bullseye as final-stage
# latest is 3.12.0a5.-slim-bullseye

# ARG & ENV definitions

ARG WEEWX_UID=421
ARG WEEWX_HOME="/home/weewx"
ARG WEEWX_VERSION="4.10.2"
ARG OS_LOCALE="/usr/lib/locale/locale-archive"
ENV TZ="Europe/London"

RUN addgroup --system --gid ${WEEWX_UID} weewx && \
	adduser --system --uid ${WEEWX_UID} --ingroup weewx weewx

# install required packages for target system

RUN apt-get update && apt-get install -qy libusb-1.0-0 gosu busybox-syslogd tzdata nano

# Copy key files set up in install-weewx-stage

WORKDIR ${WEEWX_HOME}
COPY --from=install-weewx-stage /opt/venv /opt/venv
COPY --from=install-weewx-stage ${WEEWX_HOME} ${WEEWX_HOME}

# Set Locale and TimeZone - best to use explicit form of en_GB.UTF-8, rather than OS-LOCALE

RUN apt-get update && \
	apt-get install -qy apt-utils locales && \
	echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen en_GB.UTF-8	locale
ENV LANG en_GB.UTF-8

# create the data volume for binding to host folders (in /opt/weewx on the host)

RUN mkdir -p /data
VOLUME ["/data"]

# set PATH variables in correct order and start the container

ENV PATH="/opt/venv/bin:$PATH"
ENV PATH="/data/bin:$PATH"
ENV PATH="/data/util/scripts:$PATH"
# ENTRYPOINT ["./entrypoint.sh"]
# CMD ["/data/weewx.conf"]

CMD["/home/weewx/bin/weewxd","/data/weewx.conf"] for simplicity
