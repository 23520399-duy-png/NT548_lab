# syntax=docker/dockerfile:1
# nginx-unprivileged: chạy bằng user 101, lắng nghe port 8080 (không cần root)
FROM nginxinc/nginx-unprivileged:1.29-alpine
LABEL org.opencontainers.image.title="nt548-gateway" \
      org.opencontainers.image.description="NT548 Lab 02 - API gateway + UI (nginx)"
ENV PRODUCT_SERVICE_URL=http://product-service:8000 \
    ORDER_SERVICE_URL=http://order-service:3000 \
    NGINX_ENVSUBST_FILTER="_SERVICE_URL$"
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY html/ /usr/share/nginx/html/
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/health"]
