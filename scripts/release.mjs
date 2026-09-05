import { existsSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const bump = process.argv[2] ?? ''
const dir = process.argv[3] ?? ''
const usage = 'usage: npm run <major|patch> -- <os>/<os_ver>/<service>/<service_ver>'

function fail(message) {
  console.error(message)
  process.exit(1)
}

function run(command, args, extraEnv) {
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: 'inherit',
    shell: true,
    env: extraEnv ? { ...process.env, ...extraEnv } : process.env,
  })
  if (result.status !== 0) {
    process.exit(result.status ?? 1)
  }
}

function readVersion(file) {
  if (!existsSync(file)) {
    return '0.0'
  }
  const text = readFileSync(file, 'utf8').trim()
  return text === '' ? '0.0' : text
}

function bumpVersion(current, kind) {
  const match = /^(\d+)\.(\d+)$/.exec(current)
  if (!match) {
    fail(`invalid VERSION "${current}"; expected X.Y`)
  }
  const major = Number(match[1])
  const patch = Number(match[2])
  return kind === 'major' ? `${major + 1}.0` : `${major}.${patch + 1}`
}

if (bump !== 'major' && bump !== 'patch') {
  fail(usage)
}

if (!/^[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+$/.test(dir)) {
  fail(usage)
}

if (dir.split('/').some((segment) => segment === '.' || segment === '..')) {
  fail(`invalid path segment in ${dir}`)
}

const dockerfile = path.join(root, ...dir.split('/'), 'Dockerfile')
if (!existsSync(dockerfile)) {
  fail(`missing ${dir}/Dockerfile`)
}

run('git', ['pull'])

const versionFile = path.join(root, ...dir.split('/'), 'VERSION')
const next = bumpVersion(readVersion(versionFile), bump)

run(
  'npm',
  [
    'exec',
    '--',
    'np',
    bump,
    '--yolo',
    '--no-publish',
    '--no-release-draft',
    `--message="release ${dir} v${next}"`,
  ],
  {
    RELEASE_DIR: dir,
    RELEASE_VERSION: next,
  },
)
