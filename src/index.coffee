fs = require 'fs'
path = require 'path'
url = require 'url'

cjse = require 'commonjs-everywhere'
escodegen = require 'escodegen'
esmangle = require 'esmangle'
mktemp = require 'mktemp'
npm = require 'npm'
rimraf = require 'rimraf'

pkg = 'escodegen'
version = 'latest'

escodegenFormat =
  indent:
    style: ''
    base: 0
  renumber: yes
  hexadecimal: yes
  quotes: 'auto'
  escapeless: yes
  compact: yes
  parentheses: no
  semicolons: no

npm.load {}, ->
  npm.commands.info ["#{pkg}@#{version}"], (err, infoResult) ->
    throw err if err
    registryEntry = entry for own v, entry of infoResult

    if version is 'latest'
      version = registryEntry.version

    cacheFile = path.resolve path.join 'cache', "#{pkg}@#{version}-#{registryEntry.dist.shasum}.js"
    if fs.existsSync cacheFile
      console.dir fs.readFileSync cacheFile
      return

    tempBuildDir = mktemp.createDirSync path.resolve path.join 'build', "#{pkg}@#{version}--XXXXXX"
    fs.writeFileSync (path.join tempBuildDir, 'package.json'), '{"name": "name"}'
    npm.prefix = tempBuildDir

    npm.commands.install [registryEntry.dist.tarball], (err, installOutput) ->
      if err
        rimraf.sync tempBuildDir
        throw err

      root = path.normalize path.join tempBuildDir, 'node_modules', pkg
      entryFile = path.join root, (registryEntry.main or 'index.js')
      outputFile = path.normalize path.join tempBuildDir, 'bundle.js'

      pkgSlug = pkg.replace(/^[^$_a-z]/i, '_').replace(/[^a-z0-9$_]/ig, '_')
      bundle = cjse.cjsify entryFile, root, export: pkgSlug, ignoreMissing: yes
      bundle = esmangle.mangle (esmangle.optimize bundle), destructive: yes
      js = escodegen.generate bundle, format: escodegenFormat

      fs.writeFileSync outputFile, js
      fs.renameSync outputFile, cacheFile
      rimraf.sync tempBuildDir

      console.dir js
