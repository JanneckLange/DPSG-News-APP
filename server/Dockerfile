FROM node:20-alpine

ARG BUILD_TIME_UTC=unknown
ARG GIT_SHA=unknown
ARG GIT_REF=local-dev

WORKDIR /usr/src/app

ENV BUILD_TIME_UTC=${BUILD_TIME_UTC}
ENV GIT_SHA=${GIT_SHA}
ENV GIT_REF=${GIT_REF}

LABEL org.opencontainers.image.created=${BUILD_TIME_UTC}
LABEL org.opencontainers.image.revision=${GIT_SHA}
LABEL org.opencontainers.image.ref.name=${GIT_REF}

COPY package.json package-lock.json ./
RUN npm install

COPY . ./
RUN npm run build

EXPOSE 3000

CMD ["node", "dist/index.js"]
