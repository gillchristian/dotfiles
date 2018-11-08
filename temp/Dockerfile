FROM ubuntu:xenial

RUN apt-get update && \
      apt-get install -y curl node

RUN curl -o- -L https://yarnpkg.com/install.sh | bash

RUN yarn global add nvm

RUN nvm use

CMD ["node -v"]
