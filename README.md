# wp-test-runner-ex

**The project has moved to https://github.com/Automattic/vip-container-images/tree/master/wp-test-runner**

[![Build Docker image](https://github.com/sjinks/wp-test-runner-ex/actions/workflows/build-image.yml/badge.svg)](https://github.com/sjinks/wp-test-runner-ex/actions/workflows/build-image.yml)
[![Image Security Scan](https://github.com/sjinks/wp-test-runner-ex/actions/workflows/imagescan.yml/badge.svg)](https://github.com/sjinks/wp-test-runner-ex/actions/workflows/imagescan.yml)

Test runner for WordPress plugins

## Usage

```bash
docker run \
	--network "${NETWORK_NAME}" \
	-e WORDPRESS_VERSION \
	-e WP_MULTISITE \
	-e MYSQL_USER \
	-e MYSQL_PASSWORD \
	-e MYSQL_DATABASE \
	-e MYSQL_HOST \
	-v "$(pwd):/app" \
	wildwildangel/wp-test-runner-ex
```

**Parameters and environment variables:**
  * `NETWORK_NAME` is the name of the network (created with `docker network create`) where MySQL server resides.
  * `WORDPRESS_VERSION` is the version of WordPress to use. If the version specified is not among the preinstalled ones, it will be downloaded and configured. Preinstalled versions:
    * 5.3.9
    * 5.4.7
    * 5.5.6
    * 5.6.5
    * 5.7.3
    * 5.8.1 (aliased as `latest`)
    * nightly
  * `WP_MULTISITE`: 0 if run tests for the "single site" mode, 1 for the WPMU mode
  * `MYSQL_USER`: MySQL user name (defaults to `wordpress`)
  * `MYSQL_PASSWORD`: MySQL user password (defaults to `wordpress`)
  * `MYSQL_DATABASE`: MySQL database for tests (defaults to `wordpress_test`). **WARNING:** this must be an empty database, as its content will be erased.
  * `MYSQL_HOST`: hostname where MySQL server runs
  * `PHPUNIT_VERSION`: version of PHPUnit to use. Preinstalled versions are 7, 8, and 9 (the image uses the latest stable versions provided on the [official website](https://phar.phpunit.de/)). By default, the system uses PHPUnit 7.x
  * `PHP_VERSION`: version of PHP to run the tests. Currently available versions are 7.3, 7.4, 8.0, and 8.1. PHP is installed from the [ondrej/php](https://launchpad.net/~ondrej/+archive/ubuntu/php) PPA. By default, the system uses PHP 7.4
  * `DISABLE_XDEBUG`: if set to a non-empty string, the runner disables the XDebug extension (this can be useful for performance reasons)

## Internals

First, the startup scrip checks whether the requested WordPress and WordPress test library are available. If they are not, it tries to download and install them (check the `install-wp.sh` for details).

The, if the user has provided the `PHP_VERSION` environment variable, and `/usr/bin/php${PHP_VERSION}` exists, the script uses [`update-alternatives`](https://manpages.ubuntu.com/manpages/focal/en/man1/update-alternatives.1.html) to set the versoin of PHP.

If the user has specified a non-empty value for the `DISABLE_XDEBUG` environment variable, the script will use `php -d xdebug.mode=Off` to run tests. Otherwise, it will use `php`.

The startup script expects that the application to test will be mounted into the `/app` directory. It checks if `/app/phpunit.xml` or `/app/phpunit.xml.dist` file exists. If it does not, the script complains and terminates.

The the script chooses the version of PHPUnit to use. If the environment variable `PHPUNIT_VERSION` is not provided, and `/app/vendor/bin/phpunit` exists, it will be used as the PHPUnit. Otherwise, if the user has provided the `PHPUNIT_VERSION` variable, and `/usr/local/bin/phpunit${PHPUNIT_VERSION}` exists, the system will use it. Otherwise, the script will fall back to the preinstalled PHPUnit (`~/.composer/vendor/bin/phpunit`).

To run your tests, the script invokes

```bash
${PHP} -f "${PHPUNIT}" -- "$@"
```

## Sample Script to Run Tests

```bash
#!/bin/sh

set -x

export WORDPRESS_VERSION="${1:-latest}"
export WP_MULTISITE="${2:-0}"

if [ $# -ge 2 ]; then
	shift 2
elif [ $# -ge 1 ]; then
	shift 1
fi

echo "--------------"
echo "Will test with WORDPRESS_VERSION=${WORDPRESS_VERSION} and WP_MULTISITE=${WP_MULTISITE}"
echo "--------------"
echo

MARIADB_VERSION="10.3"
UUID=$(date +%s000)
NETWORK_NAME="tests-${UUID}"

export MYSQL_HOST="db-${UUID}"
export MYSQL_USER=wordpress
export MYSQL_PASSWORD=wordpress
export MYSQL_DATABASE=wordpress_test
export MYSQL_ROOT_PASSWORD=wordpress
export MYSQL_INITDB_SKIP_TZINFO=1

docker network create "${NETWORK_NAME}"
db=$(docker run --network "${NETWORK_NAME}" --name "${MYSQL_HOST}" -e MYSQL_ROOT_PASSWORD -e MARIADB_INITDB_SKIP_TZINFO -e MYSQL_USER -e MYSQL_PASSWORD -e MYSQL_DATABASE -d "mariadb:${MARIADB_VERSION}")

cleanup() {
	docker rm -f "${db}"
	docker network rm "${NETWORK_NAME}"
}

trap cleanup EXIT

docker run \
	--network "${NETWORK_NAME}" \
	-e WORDPRESS_VERSION \
	-e WP_MULTISITE \
	-e MYSQL_USER \
	-e MYSQL_PASSWORD \
	-e MYSQL_DATABASE \
	-e MYSQL_HOST \
	-v "$(pwd):/app" \
	wildwildangel/wp-test-runner-ex "/usr/local/bin/runner" "$@"
```
