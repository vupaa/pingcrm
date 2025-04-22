#!/bin/sh
php /var/www/html/artisan optimize
php /var/www/html/artisan migrate --force

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
