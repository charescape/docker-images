镜像使用文档在 `docker-images-docs` 仓库，路径与本仓镜像目录一一对应，例如 `ubuntu/24.04/mariadb/12.3/README.md`。

目录结构：

```
<os>/<os_ver>/<service>/<service_ver>/Dockerfile
<os>/<os_ver>/<service>/<service_ver>/VERSION
```

`VERSION` 为两段式版本号（`1.0`、`1.1`、`2.0`），每个镜像独立维护。在仓库根目录执行：

```
npm run major -- ubuntu/24.04/mariadb/12.3
npm run patch -- ubuntu/24.04/mariadb/12.3
```

上述命令会运行 [`scripts/release.mjs`](scripts/release.mjs)：先确认 Dockerfile 存在，再提升镜像 `VERSION`（`patch` 为 `1.0` → `1.1`；`major` 为 `1.1` → `2.0`），然后用相同的 bump 类型调用 `np`（`--yolo --no-publish --no-release-draft`）更新 `package.json`、提交、打 tag 并推送。提交信息使用的是**镜像**版本：

```
release ubuntu/24.04/mariadb/12.3 v1.1
```

仓库 git tag 跟随 `np major` / `np patch`（`v2.0.0`、`v1.11.1` 等），与镜像 `VERSION` 相互独立。

[`.github/workflows/release.yml`](.github/workflows/release.yml) 会构建 `ubuntu/24.04/mariadb/12.3/Dockerfile`，并推送 `ghcr.io/<owner>/docker-images:ubuntu-24.04-mariadb-12.3-v1.1` 以及 `<DOCHUB_USERNAME>/docker-images:ubuntu-24.04-mariadb-12.3-v1.1`。每次发布对应一个新 tag。

提交信息中 `release` 之后的路径必须恰好是四段，后面跟 `v` 加 `X.Y`。
