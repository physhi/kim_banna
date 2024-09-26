FROM node:20.15.1-bookworm as BUILDER

# RUN npm install -g yarn@1.22.22
RUN npm install -g npm@10.8.2
RUN npm install -g pnpm
RUN pwd

WORKDIR /home/kibana
COPY . /home/kibana
RUN yarn kbn bootstrap --allow-root --skip-os-packages
RUN yarn build --skip-os-packages --skip-archives --release --skip-cdn-assets --epr-registry production

FROM node:20.15.1-bookworm

ENV ARTIFACT_NAME=kibana-8.15.2
ENV APP_HOME=/usr/share/kibana

WORKDIR $APP_HOME
COPY --from=BUILDER /home/kibana/build/default/$ARTIFACT_NAME-linux-x86_64/ $APP_HOME

RUN chown -R node:0 $APP_HOME

EXPOSE 5601
CMD ["yarn", "start"]
USER 1000:0
