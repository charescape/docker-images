import { writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const dir = process.env.RELEASE_DIR ?? ''
const version = process.env.RELEASE_VERSION ?? ''

if (!dir || !version) {
  process.exit(0)
}

if (!/^[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+$/.test(dir)) {
  console.error(`invalid RELEASE_DIR ${dir}`)
  process.exit(1)
}

if (dir.split('/').some((segment) => segment === '.' || segment === '..')) {
  console.error(`invalid path segment in ${dir}`)
  process.exit(1)
}

if (!/^\d+\.\d+$/.test(version)) {
  console.error(`invalid RELEASE_VERSION ${version}`)
  process.exit(1)
}

const relative = `${dir}/VERSION`
writeFileSync(path.join(root, ...relative.split('/')), `${version}\n`)

const result = spawnSync('git', ['add', '--', relative], {
  cwd: root,
  stdio: 'inherit',
  shell: true,
})
if (result.status !== 0) {
  process.exit(result.status ?? 1)
}
