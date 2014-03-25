# gitlab-ci-runner-testkitchen

FROM ubuntu:12.04
MAINTAINER  Bernhard Weisshuhn "bkw@codingforce.com"

# Based on https://github.com/gitlabhq/gitlab-ci-runner/blob/master/Dockerfile
# by Sytse Sijbrandij <sytse@gitlab.com>

# This script will start a runner in a docker container.
#
# First build the container and give a name to the resulting image:
# docker build -t codingforce/gitlab-ci-runner-testkitchen github.com/codingforce/gitlab-ci-runner-testkitchen
#
# Then set the environment variables and run the gitlab-ci-runner in the container:
# docker run -e CI_SERVER_URL=https://ci.example.com -e REGISTRATION_TOKEN=replaceme -e HOME=/root -e GITLAB_SERVER_FQDN=gitlab.example.com codingforce/gitlab-ci-runner-testkitchen
#
# After you start the runner you can send it to the background with ctrl-z
# The new runner should show up in the GitLab CI interface on /runners
#
# You can start an interactive session to test new commands with:
# docker run -e CI_SERVER_URL=https://ci.example.com -e REGISTRATION_TOKEN=replaceme -e HOME=/root -i -t codingforce/gitlab-ci-runner-testkitchen:latest /bin/bash
#
# If you ever want to freshly rebuild the runner please use:
# docker build -no-cache -t codingforce/gitlab-ci-runner-testkitchen github.com/codingforce/gitlab-ci-runner-testkitchen

# Update your packages and install the ones that are needed to compile Ruby
RUN apt-get update -y
RUN apt-get install -y wget curl gcc libxml2-dev libxslt-dev libcurl4-openssl-dev libreadline6-dev libc6-dev libssl-dev make build-essential zlib1g-dev openssh-server git-core libyaml-dev postfix libicu-dev

# Download Ruby and compile it
RUN mkdir /tmp/ruby && cd /tmp/ruby && curl -s http://ftp.ruby-lang.org/pub/ruby/ruby-1.9-stable.tar.bz2 | tar xj --strip-components=1
RUN cd /tmp/ruby && ./configure --disable-install-rdoc && make && make install
RUN rm -rf /tmp/ruby

# don't install ruby rdocs or ri:
RUN echo "gem: --no-rdoc --no-ri" >> /usr/local/etc/gemrc

# Fix upstart under a virtual host https://github.com/dotcloud/docker/issues/1024
# RUN dpkg-divert --local --rename --add /sbin/initctl
# RUN ln -s /bin/true /sbin/initctl

# Set the right locale
RUN echo "LC_ALL=\"en_US.UTF-8\"" >> /etc/default/locale
RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

# Prepare a known host file for non-interactive ssh connections
RUN mkdir -p /root/.ssh
RUN touch /root/.ssh/known_hosts

# Install the runner
RUN mkdir /gitlab-ci-runner && cd /gitlab-ci-runner && curl -sL https://github.com/gitlabhq/gitlab-ci-runner/archive/v4.0.0.tar.gz | tar xz --strip-components=1

# Install the gems for the runner
RUN cd /gitlab-ci-runner && gem install bundler && bundle install

# Install test-kitchen with all drivers:
RUN gem install test-kitchen
RUN gem install berkshelf
RUN gem install unf

# RUN kitchen driver discover | awk '/kitchen-/ {print $1}' | xargs gem install

# Install kitchen-openstack with fix for floating ips
RUN gem uninstall kitchen-openstack
RUN git clone https://github.com/TelekomLabs/kitchen-openstack.git /kitchen-openstack
RUN cd /kitchen-openstack && gem build kitchen-openstack.gemspec
RUN cd /kitchen-openstack && gem install kitchen-openstack-1.3.1.dev.gem

# create a volume for ssh keys
VOLUME /private

# When the image is started add the remote server key, install the runner and run it
WORKDIR /gitlab-ci-runner
CMD ssh-keyscan -H $GITLAB_SERVER_FQDN >> /root/.ssh/known_hosts & bundle exec ./bin/setup_and_run

