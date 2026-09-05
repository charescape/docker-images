Ubuntu 24.04 + MariaDB 12.3

容器启动后，runit 会拉起 `/etc/service/mariadb/run`。客户端 `my.cnf` 默认 `host=127.0.0.1` 且 `protocol=tcp`。初始化必须走 Unix socket（unix_socket 认证，OS root 免密），因此要同时覆盖这两项：只加 `--protocol=socket` 仍会连 `127.0.0.1`，在 `skip_name_resolve` 下对不上 `root@localhost`。

```bash
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY 'root12345';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "FLUSH PRIVILEGES;"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE DATABASE mydevdb;"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE DATABASE myproddb;"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE DATABASE mytestingdb;"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE USER 'devuser'@'%' IDENTIFIED BY 'dev12345';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "GRANT ALL PRIVILEGES ON mydevdb.* TO 'devuser'@'%';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE USER 'produser'@'%' IDENTIFIED BY 'prod12345';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "GRANT ALL PRIVILEGES ON myproddb.* TO 'produser'@'%';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "CREATE USER 'testinguser'@'%' IDENTIFIED BY 'testing12345';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "GRANT ALL PRIVILEGES ON mytestingdb.* TO 'testinguser'@'%';"
/usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root -e "FLUSH PRIVILEGES;"
```

## 容器内（只停/启 MariaDB，容器继续跑）

服务由 runit 管理，不要用 `mysql.server` 或 `mariadb-admin shutdown`（后者停掉后 runit 约 1 秒会再拉起）。

```bash
sv status mariadb
sv stop mariadb
sv start mariadb
sv restart mariadb
```

## 备份

自动备份默认关闭，启用 `* * * * * /usr/local/sbin/mariadb-backup.sh --scheduled` 心跳后，每天按 `MARIADB_BACKUP_HOUR` / `MARIADB_BACKUP_MINUTE`（`TZ=Asia/Shanghai`，默认 3 点 0 分）用 `mariadb-dump` 做全库逻辑备份（含 `mysql` 账号/权限、routines/events/triggers），zstd 压缩后写到 `/wwwdata/misc/backup/all-databases-YYYYMMDD-HHMMSS.sql.zst`，按 mtime 保留 30 天。失败只写日志，不告警。日志在 `/wwwdata/misc/backup/backup.log`。

**必须 bind-mount `/wwwdata/misc`**（下面 `docker run` 已有）：配置文件和备份都在这，否则会写进容器可写层。

配置在 `/wwwdata/misc/mariadb12v3.conf`（KEY=VALUE）。启动时若该文件不存在，会从 `/etc/mariadb12v3.conf.default` 拷一份。

- `MARIADB_BACKUP_ENABLE` 默认 `0`；`1` / `true` / `yes` / `on` 为开启
- `MARIADB_BACKUP_HOUR` 默认 `3`（0–23，写 `3` 不要写 `03`）
- `MARIADB_BACKUP_MINUTE` 默认 `0`（0–59，写 `0` 不要写 `00`）
- `MARIADB_BACKUP_KEEP_DAYS` 默认 `30`
- `MARIADB_BACKUP_DIR` 默认 `/wwwdata/misc/backup`

手动备份：（忽略时刻，忽略 `MARIADB_BACKUP_ENABLE`）： `/usr/local/sbin/mariadb-backup.sh`

## 恢复：

恢复会覆盖同名库，先停业务再执行：

```bash
zstd -d -c /wwwdata/misc/backup/all-databases-YYYYMMDD-HHMMSS.sql.zst | /usr/local/mysql/bin/mariadb -h localhost --protocol=socket -u root
```

## 宿主机

`--stop-timeout 360` 给 InnoDB 刷盘。未指定时默认 10 秒会被 SIGKILL。`docker stop` / `docker restart` 的 `--timeout 360` 与之相同。

`--security-opt seccomp=unconfined` 放行 `io_uring_*`。Docker 默认 seccomp 会拦住这些 syscall（EPERM），MariaDB 会落到 simulated AIO，`innodb_linux_aio=io_uring` 也就起不来。

注意事项：

- 镜像构建时已在 `/wwwdata/mysql/data` 跑过 `mariadb-install-db`；
- named volume 首次创建会拷贝镜像内已初始化的内容，不要对这两个路径 bind mount 空目录；
- 另外，最好也不要事先执行 `docker volume create`；
- `-v vol_wwwdata_mariadb12v3_data:/wwwdata/mysql/data` 这种写法是 named volume；
- volume 不存在时，docker run 会自动创建；
- 如果先 `docker volume create vol_wwwdata_mariadb12v3_data`，volume 是空的，再挂上去时**不会**再拷镜像内容，MariaDB 会面对空 datadir，启动会失败或需要重新初始化；
- 所以正确做法就是直接跑这条 docker run，让 Docker 自己建这两个 volume。

确认 volume 是否已由这次启动创建：`docker volume ls | grep vol_wwwdata_mariadb12v3`

```bash
docker network inspect my_shared_net >/dev/null 2>&1 || docker network create my_shared_net
mkdir -p /dockerdata/my_shared_dir
chown -R www-data:www-data /dockerdata

docker run -d \
  --name mariadb12v3 \
  --hostname hostmariadb12v3 \
  --network my_shared_net \
  --restart unless-stopped \
  --stop-timeout 360 \
  -p 0.0.0.0:3306:3306 \
  -e TZ=Asia/Shanghai \
  -e KILL_PROCESS_TIMEOUT=300 \
  -e KILL_ALL_PROCESSES_TIMEOUT=300 \
  --ulimit nofile=65535:65535 \
  --ulimit nproc=65535:65535 \
  --security-opt seccomp=unconfined \
  --shm-size=1g \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v vol_wwwdata_mariadb12v3_data:/wwwdata/mysql/data \
  -v vol_wwwdata_mariadb12v3_run:/wwwdata/mysql/run \
  -v /dockerdata/mariadb12v3/wwwdata_misc:/wwwdata/misc \
  -v /dockerdata/my_shared_dir:/my_shared_dir \
  <镜像>

docker ps
docker logs -f mariadb12v3

docker exec -t -i mariadb12v3 bash -l

docker stop --timeout 360 mariadb12v3
docker start mariadb12v3
docker restart --timeout 360 mariadb12v3
```

## 注意事项：

进入容器用 `docker exec -t -i mariadb12v3 bash -l`。不要 `docker run -it … bash`（会跳过 `/sbin/my_init`，runit 和 MariaDB 都不会起来）。不要 `docker attach` 再 Ctrl-C（可能把 PID 1 一起停掉）。

`docker rm mariadb12v3` 只删容器；数据在 volume 里还在。
