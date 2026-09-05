Ubuntu 24.04 + OpenResty 1.31 + PHP 8.4

容器启动后，runit 会拉起 `/etc/service/openresty/run` 和 `/etc/service/php-fpm/run`。nginx master 与 php-fpm master 均以 root 运行，worker 为 `www-data`。OpenResty 默认监听 `80`；PHP-FPM 只绑 `127.0.0.1:9000`，其它容器连不到。镜像 `PATH` 已包含 `/usr/local/openresty/nginx/sbin`、`/usr/local/php/bin` 和 `/usr/local/php/sbin`（composer 的 shebang 是 `#!/usr/bin/env php`）：

```bash
nginx -v
nginx -t
php -v
php -m
php-fpm --fpm-config /usr/local/php/etc/php-fpm.conf -t
composer --version
```

## 容器内（只停/启服务，容器继续跑）

服务由 runit 管理。不要 `nginx -s stop` / `nginx -s quit`，也不要直接 `kill` php-fpm（停掉后 runit 约 1 秒会再拉起）。

改 `nginx.conf`、`http.d` / `rtmp.d` 站点配置，或更换 `ssl/` 下的证书之后，用 `nginx -t` 检查通过，再 `nginx -s reload`。reload 只让 master 重读配置并平滑替换 worker，已有连接尽量走完，服务不中断。不要为此 `sv restart openresty`：restart 会先停掉再拉起整条 nginx 进程，连接会断、有短暂中断。

`sv restart openresty` 只用于进程已经不正常的情况，例如 worker 或 master 僵死、reload 失败，或者 `sv status openresty` 的输出不是以 `run:` 开头。php-fpm 同理：改池配置后 `sv restart php-fpm` 才会生效；日常不要 `kill`。

```bash
sv status openresty
sv stop openresty
sv start openresty
sv restart openresty
nginx -s reload
nginx -t

sv status php-fpm
sv stop php-fpm
sv start php-fpm
sv restart php-fpm
```

## 宿主机

`--stop-timeout 360` 给 nginx worker 走完 `worker_shutdown_timeout`、给 php-fpm worker 走完 `request_terminate_timeout`。未指定时默认 10 秒会被 SIGKILL。`docker stop` / `docker restart` 的 `--timeout 360` 与之相同。

注意事项：

- 配置和证书放 `/wwwdata/openresty/nginxconf/{http.d,rtmp.d,ssl}`；
- `session.save_path` 为 `/wwwdata/php/sessions`；
- 站点代码在 `/my_shared_dir/repos/<站点名>`（宿主机 `/dockerdata/my_shared_dir/repos/`，用 git 管理）；
- 启动脚本会 `chown -R www-data /my_shared_dir`（含 `.git`，uid 一般为 33）；
- named volume 首次创建会拷贝镜像内目录；不要对 logs / run / sessions 执行 bind mount 空目录；
- 另外，最好也不要事先执行 `docker volume create`；
- `-v vol_wwwdata_openrestyphp8v4_openresty_logs:/wwwdata/openresty/logs` 这种写法是 named volume；
- volume 不存在时，docker run 会自动创建；
- 如果先 `docker volume create vol_wwwdata_openrestyphp8v4_openresty_logs`，volume 是空的，再挂上去时**不会**再拷镜像内容（空 logs 目录一般仍可用）；
- 所以 logs / run / sessions 这类路径，正确做法就是直接跑这条 docker run，让 Docker 自己建 volume；
- `nginxconf` 用 bind mount：空目录会盖住镜像里的 placeholder，启动脚本会补一个 `00-placeholder.conf`，否则 `include *.conf` 会让 `nginx -t` 失败；
- HTTPS `server` 写在 `http.d`，证书放 `ssl/`，例如 `ssl_certificate /wwwdata/openresty/nginxconf/ssl/example.com.crt;`。

`http.d` 站点样例（`root` 必须与 PHP 里的路径一致）：

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name my_website_001.example.com;
    root /my_shared_dir/repos/my_website_001;
    index index.php index.html;
    location / { try_files $uri $uri/ /index.php$is_args$args; }
    location ~ \.php {
        set $php_fastcgi 127.0.0.1:9000;
        fastcgi_pass $php_fastcgi;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
    }
}
```

确认 volume 是否已由这次启动创建：`docker volume ls | grep vol_wwwdata_openrestyphp8v4`

```bash
docker network inspect my_shared_net >/dev/null 2>&1 || docker network create my_shared_net
mkdir -p /dockerdata/my_shared_dir/repos
mkdir -p /dockerdata/openrestyphp8v4/nginxconf
chown -R www-data:www-data /dockerdata/my_shared_dir
chown -R www-data:www-data /dockerdata/openrestyphp8v4

docker run -d \
  --name openrestyphp8v4 \
  --hostname hostopenrestyphp8v4 \
  --network my_shared_net \
  --restart unless-stopped \
  --stop-timeout 360 \
  -p 0.0.0.0:80:80 \
  -p 0.0.0.0:443:443 \
  -e TZ=Asia/Shanghai \
  -e KILL_PROCESS_TIMEOUT=300 \
  -e KILL_ALL_PROCESSES_TIMEOUT=300 \
  --ulimit nofile=65535:65535 \
  --ulimit nproc=65535:65535 \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v vol_wwwdata_openrestyphp8v4_openresty_logs:/wwwdata/openresty/logs \
  -v vol_wwwdata_openrestyphp8v4_openresty_run:/wwwdata/openresty/run \
  -v vol_wwwdata_openrestyphp8v4_php_sessions:/wwwdata/php/sessions \
  -v vol_wwwdata_openrestyphp8v4_php_run:/wwwdata/php/run \
  -v /dockerdata/openrestyphp8v4/nginxconf:/wwwdata/openresty/nginxconf \
  -v /dockerdata/openrestyphp8v4/wwwdata_misc:/wwwdata/misc \
  -v /dockerdata/my_shared_dir:/my_shared_dir \
  <镜像>

docker ps
docker logs -f openrestyphp8v4

docker exec -t -i openrestyphp8v4 bash -l

docker stop --timeout 360 openrestyphp8v4
docker start openrestyphp8v4
docker restart --timeout 360 openrestyphp8v4
```

## 注意事项：

进入容器用 `docker exec -t -i openrestyphp8v4 bash -l`。不要 `docker run -it … bash`（会跳过 `/sbin/my_init`，runit、nginx 和 php-fpm 都不会起来）。不要 `docker attach` 再 Ctrl-C（可能把 PID 1 一起停掉）。

`docker rm openrestyphp8v4` 只删容器；named volume 里的日志和 sessions 还在。bind mount 的 `nginxconf` 和 `/my_shared_dir` 在宿主机上。
