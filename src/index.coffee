fs = require 'fs'
path = require 'path'
url = require 'url'

cjse = require 'commonjs-everywhere'
escodegen = require 'escodegen'
esmangle = require 'esmangle'
express = require 'express'
mktemp = require 'mktemp'
npm = require 'npm'
rimraf = require 'rimraf'

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

app = express()

app.get /^\/bundle\/([^@]+)(?:@(.+))?$/, (req, res) ->
  pkg = req.params[0]
  version = req.params[1] or 'latest'

  console.dir req.params
  npm.load {}, ->
    npm.commands.info ["#{pkg}@#{version}"], (err, infoResult) ->
      throw err if err
      registryEntry = entry for own v, entry of infoResult

      if version is 'latest'
        version = registryEntry.version

      cacheFileName = "#{pkg}@#{version}-#{registryEntry.dist.shasum}.js"
      cacheFile = path.resolve path.join 'cache', cacheFileName
      if fs.existsSync cacheFile
        res.type 'javascript'
        res.attachment cacheFileName
        res.send 200, fs.readFileSync cacheFile
        return

      tempBuildDir = mktemp.createDirSync path.resolve path.join 'build', "#{pkg}@#{version}-XXXXXX"
      fs.writeFileSync (path.join tempBuildDir, 'package.json'), '{"name": "name"}'
      npm.prefix = tempBuildDir

      npm.commands.install [registryEntry.dist.tarball], (err, installOutput) ->
        if err
          rimraf.sync tempBuildDir
          res.send 500, err.toString()
          res.end()
          return

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

        res.type 'javascript'
        res.attachment cacheFileName
        res.send 200, js

app.listen 3000
console.log 'Listening on port 3000'