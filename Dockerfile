# docker buildx build --push --platform linux/amd64,linux/arm/v7 -t mouseketeers/bot:1.0.8 -t mouseketeers/bot .
# docker run --init --name test-bot --env name=ezai --cap-add=SYS_ADMIN -v %cd%/user:/usr/bot/user -v -d mouseketeers/bot

ARG BASE_IMAGE_TAG=mouseketeers/king-reward-solver:1.0.1
    
#### Stage base ########################################################################################################
FROM $BASE_IMAGE_TAG AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium fonts-freefont-ttf libxss1 \
    libpng-dev

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

#### Stage BUILD #######################################################################################################
FROM base AS build

RUN apt-get install -y --no-install-recommends \
    git \
    jq \
    openssh-client 
    
## https://vsupalov.com/build-docker-image-clone-private-repo-ssh-key/

# Download public key for github.com
RUN mkdir -p -m 0600 /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts
COPY ssh/bot_rsa ssh/config /root/.ssh/
RUN chmod 600 /root/.ssh/*

WORKDIR /usr

RUN git clone git@github.com:mouseketeers-dev/bot.git bot \
    && cd bot \
    && git checkout tags/0.6.11 \
    && jq '.dependencies."king-reward-solver" = "file:../king-reward-solver"' package.json > temp.json \ 
    && mv temp.json package.json

WORKDIR /usr/bot

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN npm i --only=production

#### Stage RELEASE #####################################################################################################
FROM base AS RELEASE

WORKDIR /usr/bot

RUN groupadd -r bot && useradd -r -g bot bot \
    && mkdir -p /home/bot \
    && mkdir -p /usr/bot \
    && chown -R bot:bot /usr/bot \
    && chown -R bot:bot /usr/king-reward-solver \
    && chown -R bot:bot /home/bot \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get -qq autoremove \
    && apt-get -qq clean

COPY --from=build --chown=bot /usr/bot /usr/bot

ENV BROWSER_MODE=headless
ENV NON_EMPTY_BLANK_LINE=1

USER bot

CMD ["npm", "run", "bot"]
