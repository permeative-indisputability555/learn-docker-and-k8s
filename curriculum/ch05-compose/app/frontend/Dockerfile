FROM nginx:1.25-alpine

LABEL app=learn-docker-k8s
LABEL chapter=ch05

# Copy custom nginx config (replaces the default server block)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the static frontend files
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
