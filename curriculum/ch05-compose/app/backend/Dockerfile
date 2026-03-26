FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL chapter=ch05

WORKDIR /app

# Copy dependency manifests first for better layer caching.
# If package.json hasn't changed, Docker skips the npm install layer.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

# Copy application source
COPY server.js ./

EXPOSE 3000

CMD ["node", "server.js"]
