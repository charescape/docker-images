#!/usr/bin/env python3
"""Issue or skip-renew Let's Encrypt certs via acme.sh docker, one domain per run.

Host runtime this script is written for:
  OS:      Ubuntu 26.04
  arch:    x86_64
  Python:  3.14 (stdlib only, including tomllib)
  Docker:  29.7
"""

from __future__ import annotations

import argparse
import fcntl
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any, TextIO

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR / "domains.toml"
LOG_PATH = SCRIPT_DIR / "issue-certs.log"
LOCK_PATH = SCRIPT_DIR / "issue-certs.lock"
CERT_ROOT = Path("/dockerdata/my_shared_dir/letsencrypt")
ACME_IMAGE = "ghcr.io/acmesh-official/acme.sh:latest"
RENEW_AFTER_SECONDS = 75 * 86400
DNS_SLEEP_SECONDS = 30
ACME_WEBROOT_IN_CONTAINER = "/acme-webroot"

DNS_PROVIDERS = {
    "aliyun": ("dns_ali", "Ali_Key", "Ali_Secret"),
    "tencent": ("dns_tencent", "Tencent_SecretId", "Tencent_SecretKey"),
    "cloudflare": ("dns_cf", None, "CF_Token"),
}
KEY_LENGTHS = {
    "ec-256": "ec-256",
    "rsa-2048": "2048",
}

log = logging.getLogger("issue-certs")


@dataclass(frozen=True)
class DomainConfig:
    domain: str
    with_www: bool
    challenge: str
    email: str
    key_algorithm: str
    reload_container_name: str
    dns_provider: str | None = None
    dns_id: str = ""
    dns_secret: str = ""
    acme_webroot: Path | None = None

    @property
    def names(self) -> list[str]:
        names = [self.domain]
        if self.with_www:
            names.append(f"www.{self.domain}")
        return names

    @property
    def dest_dir(self) -> Path:
        return CERT_ROOT / self.domain

    @property
    def fullchain_path(self) -> Path:
        return self.dest_dir / "fullchain.cer"

    @property
    def privkey_path(self) -> Path:
        return self.dest_dir / "privkey.key"

    @property
    def is_ecc(self) -> bool:
        return self.key_algorithm.startswith("ec-")


def setup_logging() -> None:
    log.setLevel(logging.INFO)
    log.handlers.clear()
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    stream = logging.StreamHandler(sys.stdout)
    stream.setFormatter(formatter)
    log.addHandler(stream)
    file_handler = logging.FileHandler(LOG_PATH, encoding="utf-8")
    file_handler.setFormatter(formatter)
    log.addHandler(file_handler)


@contextmanager
def acquire_lock(lock_path: Path) -> Iterator[TextIO | None]:
    with lock_path.open("a+", encoding="utf-8") as handle:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            yield None
            return
        handle.seek(0)
        handle.truncate()
        handle.write(str(os.getpid()))
        handle.flush()
        try:
            yield handle
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def load_raw_config(path: Path) -> dict[str, Any]:
    with path.open("rb") as fh:
        data = tomllib.load(fh)
    if not isinstance(data, dict):
        raise TypeError("domains.toml root must be a table")
    return data


def parse_domain_config(domain: str, raw: Any) -> DomainConfig:
    if not isinstance(raw, dict):
        raise TypeError(f"{domain}: section must be a table")

    missing = [
        key
        for key in ("with_www", "type", "email", "key_algorithm", "reload_container_name")
        if key not in raw
    ]
    if missing:
        raise ValueError(f"{domain}: missing fields: {', '.join(missing)}")

    with_www = raw["with_www"]
    if not isinstance(with_www, bool):
        raise TypeError(f"{domain}: with_www must be a boolean")

    challenge = str(raw["type"]).strip()
    if challenge not in {"DNS-01", "HTTP-01"}:
        raise ValueError(f"{domain}: type must be DNS-01 or HTTP-01")

    email = str(raw["email"]).strip()
    if not email:
        raise ValueError(f"{domain}: email is empty")

    key_algorithm = str(raw["key_algorithm"]).strip()
    if key_algorithm not in KEY_LENGTHS:
        raise ValueError(f"{domain}: key_algorithm must be ec-256 or rsa-2048")

    reload_container_name = str(raw["reload_container_name"]).strip()
    if not reload_container_name:
        raise ValueError(f"{domain}: reload_container_name is empty")

    dns_provider = None
    dns_id = ""
    dns_secret = ""
    acme_webroot = None

    if challenge == "DNS-01":
        dns_provider = str(raw.get("dns_provider", "")).strip()
        if dns_provider not in DNS_PROVIDERS:
            raise ValueError(f"{domain}: dns_provider must be aliyun, tencent, or cloudflare")
        creds = raw.get("dns_credentials")
        if not isinstance(creds, dict):
            raise TypeError(f"{domain}: dns_credentials must be a table")
        dns_id = str(creds.get("id", "")).strip()
        dns_secret = str(creds.get("secret", "")).strip()
        id_env = DNS_PROVIDERS[dns_provider][1]
        if not dns_secret:
            raise ValueError(f"{domain}: dns_credentials.secret is empty")
        if id_env is not None and not dns_id:
            raise ValueError(f"{domain}: dns_credentials.id is empty")
    else:
        webroot = str(raw.get("acme_webroot", "")).strip()
        if not webroot:
            raise ValueError(f"{domain}: acme_webroot is empty")
        acme_webroot = Path(webroot)

    return DomainConfig(
        domain=domain,
        with_www=with_www,
        challenge=challenge,
        email=email,
        key_algorithm=key_algorithm,
        reload_container_name=reload_container_name,
        dns_provider=dns_provider,
        dns_id=dns_id,
        dns_secret=dns_secret,
        acme_webroot=acme_webroot,
    )


def should_skip(cfg: DomainConfig, force: bool) -> bool:
    if force:
        return False
    if not cfg.fullchain_path.is_file() or not cfg.privkey_path.is_file():
        return False
    age = time.time() - cfg.fullchain_path.stat().st_mtime
    return age <= RENEW_AFTER_SECONDS


def redact_argv(argv: list[str]) -> list[str]:
    out: list[str] = []
    skip_value = False
    for item in argv:
        if skip_value:
            key = item.split("=", 1)[0]
            out.append(f"{key}=***")
            skip_value = False
            continue
        if item == "-e":
            out.append(item)
            skip_value = True
            continue
        out.append(item)
    return out


def dns_env(cfg: DomainConfig) -> dict[str, str]:
    assert cfg.dns_provider is not None
    _plugin, id_env, secret_env = DNS_PROVIDERS[cfg.dns_provider]
    env = {secret_env: cfg.dns_secret}
    if id_env is not None:
        env[id_env] = cfg.dns_id
    return env


def build_docker_cmd(cfg: DomainConfig, tmpdir: Path) -> list[str]:
    cmd = ["docker", "run", "--rm", "-i", "-v", f"{tmpdir}:/acme.sh"]
    if cfg.challenge == "HTTP-01":
        assert cfg.acme_webroot is not None
        cmd.extend(["-v", f"{cfg.acme_webroot}:{ACME_WEBROOT_IN_CONTAINER}"])
    else:
        for key, value in dns_env(cfg).items():
            cmd.extend(["-e", f"{key}={value}"])
    cmd.append(ACME_IMAGE)
    cmd.extend(["--issue", "--server", "letsencrypt"])
    cmd.extend(["--accountemail", cfg.email])
    cmd.extend(["--keylength", KEY_LENGTHS[cfg.key_algorithm]])
    if cfg.challenge == "HTTP-01":
        cmd.extend(["-w", ACME_WEBROOT_IN_CONTAINER])
    else:
        assert cfg.dns_provider is not None
        plugin = DNS_PROVIDERS[cfg.dns_provider][0]
        cmd.extend(["--dns", plugin, "--dnssleep", str(DNS_SLEEP_SECONDS)])
    for name in cfg.names:
        cmd.extend(["-d", name])
    return cmd


def run_logged(cmd: list[str]) -> int:
    log.info("running: %s", " ".join(redact_argv(cmd)))
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        stripped = line.rstrip()
        if stripped:
            log.info("%s", stripped)
    return proc.wait()


def find_acme_cert_dir(tmpdir: Path, cfg: DomainConfig) -> Path:
    ecc_dir = tmpdir / f"{cfg.domain}_ecc"
    rsa_dir = tmpdir / cfg.domain
    preferred = ecc_dir if cfg.is_ecc else rsa_dir
    fallback = rsa_dir if cfg.is_ecc else ecc_dir
    for path in (preferred, fallback):
        if (path / "fullchain.cer").is_file() and (path / f"{cfg.domain}.key").is_file():
            return path
    raise FileNotFoundError(
        f"{cfg.domain}: issued files not found under {preferred} or {fallback}"
    )


def ensure_dest_dir(cfg: DomainConfig) -> None:
    dest = cfg.dest_dir
    if dest.is_dir():
        return
    dest.mkdir(parents=True, exist_ok=True)
    log.info("created %s", dest)


def atomic_copy(src: Path, dest: Path, mode: int) -> None:
    tmp = dest.with_name(dest.name + ".tmp")
    shutil.copyfile(src, tmp)
    os.chmod(tmp, mode)
    os.replace(tmp, dest)


def copy_certs(tmpdir: Path, cfg: DomainConfig) -> None:
    src_dir = find_acme_cert_dir(tmpdir, cfg)
    ensure_dest_dir(cfg)
    atomic_copy(src_dir / "fullchain.cer", cfg.fullchain_path, 0o644)
    atomic_copy(src_dir / f"{cfg.domain}.key", cfg.privkey_path, 0o600)
    log.info("copied certs to %s", cfg.dest_dir)


def reload_nginx(container: str) -> None:
    cmd = ["docker", "exec", container, "nginx", "-s", "reload"]
    rc = run_logged(cmd)
    if rc != 0:
        raise RuntimeError(f"nginx reload failed in container {container} (exit {rc})")


def issue_one(cfg: DomainConfig) -> None:
    if cfg.challenge == "HTTP-01":
        assert cfg.acme_webroot is not None
        if not cfg.acme_webroot.is_dir():
            raise FileNotFoundError(f"{cfg.domain}: acme_webroot does not exist: {cfg.acme_webroot}")

    tmpdir = Path(tempfile.mkdtemp(prefix=f"issue-certs-{cfg.domain}-"))
    try:
        rc = run_logged(build_docker_cmd(cfg, tmpdir))
        if rc != 0:
            raise RuntimeError(f"{cfg.domain}: acme.sh exited {rc}")
        copy_certs(tmpdir, cfg)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
        log.info("removed temp acme.sh dir for %s", cfg.domain)
    reload_nginx(cfg.reload_container_name)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Issue Let's Encrypt certs with acme.sh docker")
    parser.add_argument("--force", action="store_true", help="reissue even if cert is younger than 75 days")
    parser.add_argument(
        "--domain",
        action="append",
        default=[],
        dest="domains",
        metavar="DOMAIN",
        help="only process this domain (repeatable)",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    setup_logging()

    with acquire_lock(LOCK_PATH) as lock:
        if lock is None:
            log.info("another issue-certs.py is running; skip")
            return 0
        if not CONFIG_PATH.is_file():
            log.error("missing config: %s", CONFIG_PATH)
            return 1

        try:
            raw = load_raw_config(CONFIG_PATH)
        except (OSError, tomllib.TOMLDecodeError, TypeError, ValueError) as exc:
            log.error("failed to read %s: %s", CONFIG_PATH, exc)
            return 1

        selected = list(args.domains)
        if selected:
            unknown = [name for name in selected if name not in raw]
            names = [name for name in selected if name in raw]
        else:
            unknown = []
            names = list(raw.keys())

        failed = 0
        for name in unknown:
            log.error("domain not in domains.toml: %s", name)
            failed += 1

        for name in names:
            try:
                cfg = parse_domain_config(name, raw[name])
            except (TypeError, ValueError) as exc:
                log.error("%s", exc)
                failed += 1
                continue

            if should_skip(cfg, args.force):
                log.info("skip %s: cert younger than 75 days", cfg.domain)
                continue

            log.info("issue %s (%s)", cfg.domain, ",".join(cfg.names))
            try:
                issue_one(cfg)
                log.info("done %s", cfg.domain)
            except Exception as exc:
                log.error("failed %s: %s", cfg.domain, exc)
                failed += 1

        if failed:
            log.error("finished with %s failure(s)", failed)
            return 1
        log.info("finished with no failures")
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
