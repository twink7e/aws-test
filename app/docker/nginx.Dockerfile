FROM nginx:stable-alpine

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY public/ /var/www/html/public/
USER nginx
EXPOSE 8080
ENTRYPOINT ["nginx", "-g", "daemon off;"]
