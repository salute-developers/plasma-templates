FROM node:22

WORKDIR /app

# Копируем только необходимые файлы
COPY ./main.sh ./main.sh
COPY ./publisher.js ./publisher.js

# Делаем скрипты исполняемыми
RUN chmod +x ./main.sh \
    && chmod +x ./publisher.js

RUN npm install -g node-gyp

COPY ./ds-generator-cli.tgz .

# Unpack ds-generator project and install deps
RUN mkdir -p /app/ds-generator \
    && tar -xzf ds-generator-cli.tgz -C /app/ds-generator --strip-components=0 \
    && cd /app/ds-generator \
    && npm install \
    && npm run build

# Make CLI binaries available globally in the container session
ENV PATH="/app/ds-generator/node_modules/.bin:${PATH}"

# ENV NODE_ENV=production

ENTRYPOINT ["/app/main.sh"]