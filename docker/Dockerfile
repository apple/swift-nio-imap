ARG swift_version=nightly
ARG ubuntu_version=focal
ARG swift_repo=swiftlang/swift
ARG base_image=$swift_repo:$swift_version-$ubuntu_version
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# dependencies
RUN apt-get update && apt-get install -y wget
RUN apt-get update && apt-get install -y lsof dnsutils netcat-openbsd net-tools curl jq # used by integration tests

# ruby and jazzy for docs generation
 RUN apt-get update && apt-get install -y ruby ruby-dev libsqlite3-dev build-essential
 # switch of gem docs building
 RUN echo "gem: --no-document" > ~/.gemrc
 # jazzy no longer works on xenial as ruby is too old.
 RUN if [ "${ubuntu_version}" != "xenial" ] ; then  gem install jazzy; fi

# tools
RUN mkdir -p $HOME/.tools
RUN echo 'export PATH="$HOME/.tools:$PATH"' >> $HOME/.profile
