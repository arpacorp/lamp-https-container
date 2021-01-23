FROM ubuntu:focal

ENV OS_LOCALE="en_US.UTF-8"
RUN apt-get update && apt-get install -y locales && locale-gen ${OS_LOCALE}

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    DEBIAN_FRONTEND=noninteractive

ENV APACHE_CONF_DIR=/etc/apache2 \
    PHP_CONF_DIR=/etc/php/5.6 \
    PHP_DATA_DIR=/var/lib/php


RUN	\
	BUILD_DEPS='software-properties-common' \
  && dpkg-reconfigure locales \
	&& apt-get install --no-install-recommends -y $BUILD_DEPS \

	&& add-apt-repository -y ppa:ondrej/php \
	&& add-apt-repository -y ppa:ondrej/apache2 \

	&& apt-get update \
    	&& apt-get install -y curl nano apache2 supervisor libapache2-mod-php5.6 php5.6-cli php5.6-readline php5.6-mbstring php5.6-fpm php5.6-imap php5.6-zip php5.6-intl php5.6-xml php5.6-json php5.6-curl php5.6-gd php5.6-pgsql php5.6-mysql php-pear \
	# Apache settings
	&& cp /dev/null ${APACHE_CONF_DIR}/conf-available/other-vhosts-access-log.conf \
	&& rm ${APACHE_CONF_DIR}/sites-enabled/000-default.conf ${APACHE_CONF_DIR}/sites-available/000-default.conf \
	&& a2enmod rewrite php5.6 headers http2 proxy proxy_fcgi ssl setenvif \
	# Install composer
	&& curl -sS https://getcomposer.org/installer | php -- --version=1.10.10 --install-dir=/usr/local/bin --filename=composer \
	# Cleaning
  && apt-get purge -y --auto-remove $BUILD_DEPS \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* \
  	# Forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/apache2/access.log \
  && ln -sf /dev/stderr /var/log/apache2/error.log \
  && chown www-data:www-data ${PHP_DATA_DIR} -Rf
#RUN usermod -u $UUID www-data

RUN	\
  curl -sL https://deb.nodesource.com/setup_12.x | bash - \
  && apt-get install nodejs

# Configure PHP-FPM
COPY ./config/apache2.conf ${APACHE_CONF_DIR}/apache2.conf
COPY ./config/app.conf ${APACHE_CONF_DIR}/sites-enabled/app.conf
COPY ./config/php.ini  ${PHP_CONF_DIR}/apache2/conf.d/custom.ini

COPY ./config/php-fpm.conf /etc/php/5.6/fpm/php-fpm.conf
COPY ./config/www.conf /etc/php/5.6/fpm/pool.d/www.conf
# Configure supervisord
COPY ./config/services.conf /etc/supervisor/conf.d/services.conf
RUN mkdir -p /var/run/php/
EXPOSE 80

VOLUME ["/var/www/html"]
WORKDIR /var/www/html/



# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/services.conf"]

# Configure a healthcheck to validate that everything is up&running
#HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80/fpm-ping
