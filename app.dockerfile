FROM node:20.18.0-slim

WORKDIR /home/perplexica

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --network-timeout 600000

COPY tsconfig.json next.config.mjs next-env.d.ts postcss.config.js drizzle.config.ts tailwind.config.ts ./
COPY src ./src
COPY public ./public

RUN mkdir -p /home/perplexica/data
RUN mkdir /home/perplexica/uploads

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1

CMD ["yarn", "dev"]