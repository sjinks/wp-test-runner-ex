FROM ubuntu:20.04

RUN \
	export DEBIAN_FRONTEND=noninteractive; \
	apt-get -qq update && apt-get -y upgrade && apt-get -qq install software-properties-common && \
	add-apt-repository -y ppa:ondrej/php && \
	apt-get -qq remove --purge software-properties-common && \
	apt-get -qq autoremove --purge && \
	apt-get -qq install php7.3 php7.3-apcu php7.3-curl php7.3-gd php7.3-gmp php7.3-igbinary php7.3-imagick php7.3-imap php7.3-intl php7.3-mbstring php7.3-mysql php7.3-sqlite3 php7.3-xdebug php7.3-xml php7.3-xsl php7.3-zip && \
	apt-get -qq install php7.4 php7.4-apcu php7.4-curl php7.4-gd php7.4-gmp php7.4-igbinary php7.4-imagick php7.4-imap php7.4-intl php7.4-mbstring php7.4-mysql php7.4-sqlite3 php7.4-xdebug php7.4-xml php7.4-xsl php7.4-zip && \
	apt-get -qq install php8.0 php8.0-apcu php8.0-curl php8.0-gd php8.0-gmp php8.0-igbinary php8.0-imagick php8.0-imap php8.0-intl php8.0-mbstring php8.0-mysql php8.0-sqlite3 php8.0-xdebug php8.0-xml php8.0-xsl php8.0-zip && \
	apt-get -qq install php8.1 php8.1-curl php8.1-gd php8.1-gmp php8.1-imap php8.1-intl php8.1-mbstring php8.1-mysql php8.1-sqlite3 php8.1-xml php8.1-zip && \
	apt-get -qq install git subversion jq wget unzip netcat-openbsd sudo default-mysql-client moreutils openssh-client nodejs npm && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	echo "xdebug.mode=coverage" >> /etc/php/7.3/mods-available/xdebug.ini && \
	echo "xdebug.mode=coverage" >> /etc/php/7.4/mods-available/xdebug.ini && \
	echo "xdebug.mode=coverage" >> /etc/php/8.0/mods-available/xdebug.ini && \
	update-alternatives --set php /usr/bin/php7.4

RUN \
	adduser --disabled-password --gecos "" user && \
	install -d -o user -g user -m 0777 /app /wordpress && \
	wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/bin/ --filename=composer

RUN \
	wget -q -O /usr/local/bin/phpunit7 https://phar.phpunit.de/phpunit-7.phar && chmod +x /usr/local/bin/phpunit7 && \
	wget -q -O /usr/local/bin/phpunit8 https://phar.phpunit.de/phpunit-8.phar && chmod +x /usr/local/bin/phpunit8 && \
	wget -q -O /usr/local/bin/phpunit9 https://phar.phpunit.de/phpunit-9.phar && chmod +x /usr/local/bin/phpunit9

RUN \
	echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user && \
	chmod 0440 /etc/sudoers.d/user

COPY install-wp.sh /usr/local/bin/install-wp
COPY runner.sh /usr/local/bin/runner

USER user

RUN \
	for version in $(wget https://api.wordpress.org/core/version-check/1.7/ -q -O - | jq -r '[.offers[].version] | unique | map(select( . >= "5.3")) | .[]') latest nightly; do \
		install-wp "${version}" & \
	done && \
	wait

RUN composer global require phpunit/phpunit:^7 yoast/phpunit-polyfills:^1

USER user
WORKDIR /app
VOLUME ["/app"]

CMD ["/usr/local/bin/runner"]
