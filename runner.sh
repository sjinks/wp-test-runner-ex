#!/bin/sh

set -x
set -e

: "${MYSQL_USER:="wordpress"}"
: "${MYSQL_PASSWORD:="wordpress"}"
: "${MYSQL_DB:="wordpress_test"}"
: "${MYSQL_HOST:="db"}"
: "${WORDPRESS_VERSION:="latest"}"
: "${PHPUNIT_VERSION:=""}"
: "${PHP_VERSION:=""}"
: "${DISABLE_XDEBUG:=""}"
: "${APP_HOME:="/app"}"

if [ ! -d "/wordpress/wordpress-${WORDPRESS_VERSION}" ] || [ ! -d "/wordpress/wordpress-tests-lib-${WORDPRESS_VERSION}" ]; then
	install-wp "${WORDPRESS_VERSION}"
fi

(
	cd "/wordpress/wordpress-tests-lib-${WORDPRESS_VERSION}" && \
	cp -f wp-tests-config-sample.php wp-tests-config.php && \
	sed -i "s/youremptytestdbnamehere/${MYSQL_DB}/; s/yourusernamehere/${MYSQL_USER}/; s/yourpasswordhere/${MYSQL_PASSWORD}/; s|localhost|${MYSQL_HOST}|" wp-tests-config.php && \
	sed -i "s:dirname( __FILE__ ) . '/src/':'/tmp/wordpress/':" wp-tests-config.php
)

rm -rf /tmp/wordpress /tmp/wordpress-tests-lib
ln -sf "/wordpress/wordpress-${WORDPRESS_VERSION}" /tmp/wordpress
ln -sf "/wordpress/wordpress-tests-lib-${WORDPRESS_VERSION}" /tmp/wordpress-tests-lib

if [ -n "${PHP_VERSION}" ] && [ -x "/usr/bin/php${PHP_VERSION}" ]; then
	sudo update-alternatives --set php "/usr/bin/php${PHP_VERSION}"
fi

if [ -n "${DISABLE_XDEBUG}" ]; then
	PHP="php -d xdebug.mode=Off"
else
	PHP=php
fi

echo "Waiting for MySQL..."
while ! nc -z "${MYSQL_HOST}" 3306; do
	sleep 1
done

${PHP} -v

echo "Running tests..."
if [ -f "${APP_HOME}/phpunit.xml" ] || [ -f "${APP_HOME}/phpunit.xml.dist" ]; then
	if [ -x "${APP_HOME}/vendor/bin/phpunit" ] && [ -z "${PHPUNIT_VERSION}" ]; then
		PHPUNIT="${APP_HOME}/vendor/bin/phpunit"
	elif [ -n "${PHPUNIT_VERSION}" ] && [ -x "/usr/local/bin/phpunit${PHPUNIT_VERSION}" ]; then
		PHPUNIT="/usr/local/bin/phpunit${PHPUNIT_VERSION}"
	else
		PHPUNIT=~/.composer/vendor/bin/phpunit
	fi

	${PHP} -f "${PHPUNIT}" -- --version
	${PHP} -f "${PHPUNIT}" -- "$@"
else
	echo "Unable to find phpunit.xml or phpunit.xml.dist in ${APP_HOME}"
	ls -lha "${APP_HOME}"
	exit 1
fi
