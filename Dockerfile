FROM node:20.15.1-bookworm as BUILD_IMAGE

RUN npm install -g yarn@1.22.22
RUN npm install -g pnpm
RUN pwd

WORKDIR /home/kibana
COPY . /home/kibana
RUN yarn kbn bootstrap --allow-root
RUN yarn build --skip-os-packages --skip-archives --release

FROM ubuntu:20

ENV ARTIFACT_NAME=kibana-8.15.0-SNAPSHOT
ENV APP_HOME=/usr/share/kibana

RUN groupadd -g 1000 kibana && \
    adduser --uid 1000 --gid 1000 --home $APP_HOME kibana && \
    adduser kibana root && \
    chown -R 0:0 $APP_HOME

WORKDIR $APP_HOME
COPY --from=TEMP_BUILD_IMAGE /usr/app/$ARTIFACT_NAME-linux-x86_64/ $APP_HOME

EXPOSE 5601

