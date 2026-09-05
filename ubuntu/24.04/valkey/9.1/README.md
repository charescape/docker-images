Ubuntu 24.04 + Valkey 9.1

容器启动后，runit 会拉起 `/etc/service/valkey/run`。
进程以 `www-data` 运行，监听 `0.0.0.0:6379`。
ACL 在 `/wwwdata/valkey/run/users.acl`：`default` 已关闭，必须 `AUTH`。
32 个逻辑库（0–31）。镜像 `PATH` 已包含 `/usr/local/valkey/bin`：

```bash
valkey-server --version
valkey-cli --version
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a vkadmin123 ping
```

用户与库：

| 用户 | 密码 | 可访问的库 |
|------|------|------------|
| vkadmin | vkadmin123 | 0–31（全部命令） |
| vkprod | vkprod123 | 0–10 |
| vklocal | vklocal123 | 11–20 |
| vktesting | vktesting123 | 21–30 |

环境用户为 `+@all -@admin`（无 CONFIG / ACL / SHUTDOWN）。连接默认落在 DB 0。`vklocal` / `vktesting` 没有 DB 0，AUTH 后必须 `SELECT` 到自己的库，否则读写会 `NOPERM`。

```bash
valkey-cli -h <host> -p 6379 --user vkprod -a vkprod123 ping
valkey-cli -h <host> -p 6379 --user vklocal -a vklocal123 -n 11 ping
```

---

### 修改密码

上表密码是镜像默认值，部署后应立刻改掉。

#### 方法一：改 `users.acl` 再重启（推荐）

启动时会加载 `aclfile`。只改密码字段（初始文件是明文 `>vkprod123`，把 `>` 后面换成新密码），其余规则（`~*`、`&*`、`+@all`、`db=`）不要动。保存后执行`sv restart valkey`。

不要 `valkey-cli shutdown`（runit 约 1 秒会再拉起）。语法错了会起不来，修好文件再 `sv start valkey`。

#### 方法二：运行时 `ACL SETUSER`

只有 `vkadmin` 能执行 `ACL`。`resetpass` 清掉旧密码再 `>` 设新密码（不要省略 `resetpass`，否则是追加而不是替换）。shell 里 `>` 必须加引号，否则会被当成重定向。

```bash
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a vkadmin123 ACL SETUSER vkprod resetpass '>new-vkprod-pass'
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a vkadmin123 ACL SETUSER vklocal resetpass '>new-vklocal-pass'
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a vkadmin123 ACL SETUSER vktesting resetpass '>new-vktesting-pass'
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a vkadmin123 ACL SETUSER vkadmin resetpass '>new-vkadmin-pass'
valkey-cli -s /wwwdata/valkey/run/valkey.sock --user vkadmin -a 'new-vkadmin-pass' ACL SAVE
```

`ACL SAVE` 把哈希后的密码写入 `/wwwdata/valkey/run/users.acl`。已认证的连接不受影响；之后新连接用新密码。

---

## 容器内（只停/启 Valkey，容器继续跑）

服务由 runit 管理，不要 `valkey-cli shutdown`（停掉后 runit 约 1 秒会再拉起）。

```bash
sv status valkey
sv stop valkey
sv start valkey
sv restart valkey
```

## 宿主机

`--stop-timeout 360` 给 RDB / AOF 刷盘。未指定时默认 10 秒会被 SIGKILL。`docker stop` / `docker restart` 的 `--timeout 360` 与之相同。

注意事项：

- named volume 首次创建会拷贝镜像内目录；不要对这两个路径 bind mount 空目录；
- 另外，最好也不要事先执行 `docker volume create`；
- `-v vol_wwwdata_valkey9v1_data:/wwwdata/valkey/data` 这种写法是 named volume；
- volume 不存在时，docker run 会自动创建；
- 如果先 `docker volume create vol_wwwdata_valkey9v1_data`，volume 是空的，再挂上去时**不会**再拷镜像内容（空 datadir 一般仍可用，Valkey 会新建 RDB/AOF）；
- 所以正确做法就是直接跑这条 docker run，让 Docker 自己建这两个 volume。

确认 volume 是否已由这次启动创建：`docker volume ls | grep vol_wwwdata_valkey9v1`

```bash
docker network inspect my_shared_net >/dev/null 2>&1 || docker network create my_shared_net
mkdir -p /dockerdata/my_shared_dir
chown -R www-data:www-data /dockerdata

docker run -d \
  --name valkey9v1 \
  --hostname hostvalkey9v1 \
  --network my_shared_net \
  --restart unless-stopped \
  --stop-timeout 360 \
  -p 0.0.0.0:6379:6379 \
  -e TZ=Asia/Shanghai \
  -e KILL_PROCESS_TIMEOUT=300 \
  -e KILL_ALL_PROCESSES_TIMEOUT=300 \
  --ulimit nofile=65535:65535 \
  --ulimit nproc=65535:65535 \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v vol_wwwdata_valkey9v1_data:/wwwdata/valkey/data \
  -v vol_wwwdata_valkey9v1_run:/wwwdata/valkey/run \
  -v /dockerdata/valkey9v1/wwwdata_misc:/wwwdata/misc \
  -v /dockerdata/my_shared_dir:/my_shared_dir \
  <镜像>

docker ps
docker logs -f valkey9v1
docker exec -t valkey9v1 tail -f /wwwdata/valkey/run/valkey.log

docker exec -t -i valkey9v1 bash -l

docker stop --timeout 360 valkey9v1
docker start valkey9v1
docker restart --timeout 360 valkey9v1
```

## 注意事项：

进入容器用 `docker exec -t -i valkey9v1 bash -l`。不要 `docker run -it … bash`（会跳过 `/sbin/my_init`，runit 和 Valkey 都不会起来）。不要 `docker attach` 再 Ctrl-C（可能把 PID 1 一起停掉）。

`docker logs` 只有 my_init / runit。Valkey 日志在 `/wwwdata/valkey/run/valkey.log`。
