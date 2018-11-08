FROM ubuntu:xenial

RUN apt-get update && \
      apt-get -y install sudo

RUN useradd -ms /bin/bash test_user

RUN echo 'test_user ALL = NOPASSWD : ALL' >> /etc/sudoers

USER test_user

RUN mkdir -p /home/test_user/dev/dotfiles
ADD . /home/test_user/dev/dotfiles

WORKDIR /home/test_user/dev/dotfiles

CMD ["./test.sh"]
