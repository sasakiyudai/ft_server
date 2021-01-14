# FROM 命令は、イメージビルドのための処理ステージを初期化し、ベース・イメージ を設定します。

FROM debian:buster

# RUN 命令は、現在のイメージの最上位の最新レイヤーにおいて、あらゆるコマンドを実行します。 

# nginx, mariaDB, PHPなど必要なツールをダウンロードします。
# -e error発生時stop
# -u undefined env確認時stop
# -x シェルが実行される各コマンドを出力

# WordPress requires a web server on which it will serve its content.
# It is written in PHP and uses a MySQL/MariaDB database to store its information. 
# We can install Nginx, MariaDB, PHP, and other PHP modules by running the following command:

RUN set -ex; \
		apt-get update; \
		apt-get install -y --no-install-recommends \
				nginx \
				mariadb-client \
				mariadb-server \
				php7.3 \ 
				php-fpm \
				php-mysql \
				wget \
				openssl \
				vim \
				curl \
				supervisor;

# ENV <key> <value> 命令は、環境変数 <key> に <value> という値を設定します。

ENV DBNAME=wpdb USER=user PASS=password HOST=localhost

# mariaDBを設定します。-eをつければコマンドラインから実行してくれます。

RUN set -eux; \
		service mysql start; \
			mysql -e "CREATE DATABASE $DBNAME;"; \
			mysql -e "CREATE USER '$USER'@'$HOST' IDENTIFIED BY '$PASS';"; \
			mysql -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$USER'@'$HOST';"; \
			mysql -e "FLUSH PRIVILEGES;"

# wordpressをwgetします。phpmymyadminをwgetします。

RUN	set -ex;\
		mkdir -p /var/www/html/phpmyadmin; \
		wget -O phpmyadmin.tar.gz --no-check-certificate https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.tar.gz; \
		tar -xvzf phpmyadmin.tar.gz -C /var/www/html/phpmyadmin --strip-components 1; \
		rm phpmyadmin.tar.gz; \
		mkdir -p /var/www/html/wordpress; \
		wget -O wordpress.tar.gz --no-check-certificate https://wordpress.org/latest.tar.gz; \
		tar -xvzf wordpress.tar.gz -C /var/www/html/wordpress --strip-components 1; \
		rm wordpress.tar.gz; \
		chown -R www-data:www-data var/www/html/*;

# COPY <src> <dest> 命令は <src> からファイルやディレクトリを新たにコピーして、コンテナ内のファイルシステムのパス <dest> に追加します。

COPY ./srcs/wp-config.php /var/www/html/wordpress

# supervisord.conf 設定ファイルにはディレクティブ（命令）を記述します。これは Supervisor とプロセスを管理するためです。
# 複数のサービスを動かせるようになる

COPY ./srcs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /etc/supervisor/conf.d/supervisord.conf

# sslの設定　オレオレ証明書なるものを作ります
RUN set -ex; \
	mkdir -p /etc/nginx/ssl; \
	openssl genrsa -out etc/nginx/ssl/server.key 2048; \
	openssl req -new \
		-subj "/C=JP/ST=Tokyo/L=Minato/O=42/OU=42Tokyo/CN=syudai" \
		-key /etc/nginx/ssl/server.key \
		-out /etc/nginx/ssl/server.csr \
		-x509 -days 3650 -out /etc/nginx/ssl/server.crt

# 環境変数を変更したい　→　renderコマンドを使いたい　→　entrykitというンテナ内のプロセス起動時に便利な軽量 init システムをインストールする

RUN set -ex; \
		wget --no-check-certificate -O entrykit.tgz https://github.com/progrium/entrykit/releases/download/v0.4.0/entrykit_0.4.0_Linux_x86_64.tgz; \
		tar -xvzf entrykit.tgz -C /bin; \
		rm entrykit.tgz; \
		chmod +x /bin/entrykit; \
		entrykit --symlink;

# nginxの設定ファイルをコピーする。

COPY ./srcs/default.tmpl /etc/nginx/sites-available/default.tmpl

# docker image から docker container を実行するときに ENTRYPOINT の記述内容が実行されます。
# nginx内の環境変数をレンダリング(renderの指定パスは.tmplはつけない）　＆＆　/usr/bin/supervisordを実行！

ENTRYPOINT [ "render", "/etc/nginx/sites-available/default", "--", "/usr/bin/supervisord" ]

EXPOSE 80 443
