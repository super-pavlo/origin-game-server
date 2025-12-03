chmod +x etc/nginx/nginx
mkdir -p etc/nginx/logs
mkdir -p /usr/local/nginx/conf
mkdir -p /usr/local/nginx/logs
rm -rf /usr/local/nginx/conf/nginx.conf
rm -rf /usr/local/nginx/logs/nginx.pid
cp etc/nginx/nginx.conf /usr/local/nginx/conf/nginx.conf
touch /usr/local/nginx/logs/error.conf
`pwd`/etc/nginx/nginx -p `pwd`/etc/nginx -c `pwd`/etc/nginx/nginx.conf