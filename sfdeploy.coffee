fs = require("fs-extended")
async = require("async")
JSZip = require("jszip")
xmldom = require("xmldom")
path = require("path")
extend = require('util')._extend
nopt = require "nopt"

# recursive('some/path', function (err, @files) {
#   // Files is an array of filename

# });


class SFDeploy

  sfDeployOpts: 
    'checkOnly': Boolean
    'ignoreWarnings': Boolean
    'performRetrieve': Boolean
    'purgeOnDelete': Boolean
    'rollbackOnError': Boolean
    'runAllTests': Boolean
    'runTests': Boolean
    'singlePackage': Boolean
    'allowMissingFiles': Boolean
    'autoUpdatePackage': Boolean
    'runPackagedTestsOnly': Boolean
    'useDefaultMetadata': Boolean
    'usePackageXml': Boolean
    'apiVersion': String
    'filter': [String, Array]
  # knownArgs:
    # '--use-default-metadata': Boolean
    # '--use-package-xml': Boolean
    # '--print-package-xml': Boolean
    # '--api-version': String
  shortHands: {}

  rootPath: null
  currentDeployStatus: {}
  options: {}
  deployCheckCB: ->
  conn: null
  metadata:
    metadataObjects: [

    ]
  filterBy: []
  files:{}
  dirs:[]
  testFiles:[]
  allowedDeployOptions: [
    'checkOnly',
    'ignoreWarnings',
    'performRetrieve',
    'purgeOnDelete',
    'rollbackOnError',
    'runAllTests',
    'runTests',
    'singlePackage',
    'allowMissingFiles',
    'autoUpdatePackage',
    'runPackagedTestsOnly'
  ]
  deployOptions:
    # checkOnly:false
    # ignoreWarnings:false
    # performRetrieve:false
    # purgeOnDelete:false
    rollbackOnError:false
    runAllTests:false
    runTests:[]
    # singlePackage:true
    # allowMissingFiles:true
    # autoUpdatePackage:false
  showAllText: false



  constructor: (rootPath, filterByOld, conn, options) ->   
    @rootPath = rootPath
    @conn = conn
    @filterBy = Array::concat([], options.filter) || filterBy
    @files = {}
    @dirs = []

    @options = options || nopt(@sfDeployOpts, @shortHands)
    for key, val of options when key in @allowedDeployOptions
      v = val
      if val is "true" then v = true
      if val is "false" then v = false

      @deployOptions[key] = v
    if not @options.apiVersion?
      @options.apiVersion = '33.0';

  packagexml: (cb) ->
    @options.printPackageXml = true
    @options.useDefaultMetadata = true
    @deploy()

  getMetadata: (cb) ->
    if @options.useDefaultMetadata is true
      @metadata = require "@spm/sf-default-metadata"
      @getMetaDirs()
      cb(null, @metadata)
    else
      return cb?('blah') unless @conn?
      @conn.metadata.describe @options.apiVersion
      .then (meta) =>
        @metadata = meta
        @getMetaDirs()
        cb? null, meta
      ,(err) ->
        cb? err

  getMetaDirs: ->
    @dirs = []
    for dir in @metadata.metadataObjects
      @dirs.push dir.directoryName

  pathFilter: (itemPath) =>

    match = itemPath.match (/src\/(.*?)\//)

    # if itemPath.indexOf("-meta.xml") isnt -1
    #   return false

    if(itemPath.indexOf('src/package.xml') isnt -1) 
      return @options.usePackageXml

    if (match? and match.length > 1 and match[1] in @dirs) or @dirs.length == 0

      return true unless @filterBy.length > 0
      i = 0

      while i < @filterBy.length
        item = @filterBy[i]
        re = new RegExp(item)
        return true if re.test(itemPath)
        i++
    
    return false

  createFileList: (cb) ->

    areadFile = (item,cb) =>
      fs.readFile path.join(@rootPath, item),{flag:"r"},(er,results) ->
        cb(er,results)

    fs.listFiles path.resolve(@rootPath),
      filter: @pathFilter
      recursive: 1
    , (err, files) =>
      async.map files, areadFile, (er,results) =>

        for data, i in results
          @files[files[i]] = data
          if @deployOptions.runPackagedTestsOnly
            if data.toString('utf8').indexOf('@isTest') isnt -1
              @deployOptions.runTests.push files[i].match(/[^\/]*(?=\.[^.]+($|\?))/)[0]

        cb? null, @files, @testFiles

  getTextFiles: () ->
    textFiles = {}
    for key, data of @files
      textFiles[key] = 
        text: data.toString('utf-8')

    return textFiles

  parseResult: (result) ->
    # checkOnly
    # completedDate
    # createdBy
    # createdByName
    # createdDate
    # details
    # done
    # id
    # ignoreWarnings
    # lastModifiedDate
    # numberComponentErrors
    # numberComponentsDeployed
    # numberComponentsTotal
    # numberTestErrors
    # numberTestsCompleted
    # numberTestsTotal
    # rollbackOnError
    # runTestsEnabled
    # startDate
    # status
    # success
    return null unless result?
    parsed = result

    parsed.createdDate = new Date(parsed.createdDate)
    parsed.lastModifiedDate = new Date(parsed.lastModifiedDate)
    parsed.startDate = new Date(parsed.startDate)
    parsed.completedDate = new Date(parsed.completedDate)

    parsed.files = {}
    return parsed unless result.details?
    components = Array::concat(result.details?.componentSuccesses, result.details?.componentFailures)

    total = 
      locations: 0
      notCovered: 0
      percentage: 0
      num: 0

    for item in components when item?

      for key, data of @files when key.indexOf(item.fileName.replace('unpackaged/', '')) isnt -1
        
        parsed.files[key] = extend item
        if @showAllText or key.indexOf('.cls') isnt -1 or key.indexOf('.trigger') isnt -1
          parsed.files[key].text = data.toString('utf-8')

        parsed.files[key].createdDate = new Date(parsed.files[key].createdDate)
        break

    return parsed unless result.details.runTestResult?.codeCoverage?

    for item in result.details.runTestResult?.codeCoverage
      if item.type is 'Class'
        for key, data of @files when key.indexOf('classes/' + item.name + '.cls') >= 0
          break unless parsed.files[key]?
          parsed.files[key].testResults = extend item
          parsed.files[key].testResults.locationsNotCovered = Array::concat parsed.files[key].testResults.locationsNotCovered

          break if item.numLocations == null or item.numLocationsNotCovered == null
          
          parsed.files[key].testResults.coveragePercentage = 100 * ( parseInt(item.numLocations) - parseInt(item.numLocationsNotCovered) ) / parseInt(item.numLocations)
          total.locations += parseInt item.numLocations
          total.notCovered += parseInt item.numLocationsNotCovered
          total.num++
          console.log total
          break

      if item.type is 'Trigger'
        for key, data of @files when key.indexOf('triggers/' + item.name + '.trigger') >= 0
          break unless parsed.files[key]?
          parsed.files[key].testResults = extend item
          
          break if item.numLocations == null or item.numLocationsNotCovered == null

          parsed.files[key].testResults.coveragePercentage = 100 * ( parseInt(item.numLocations) - parseInt(item.numLocationsNotCovered) ) / parseInt(item.numLocations)
          total.locations += parseInt item.numLocations
          total.notCovered += parseInt item.numLocationsNotCovered
          total.num++
          break

    parsed.totalCoverage = if total.num is 0 then 0 else total.locations - total.notCovered  / total.num

    return parsed

  checkStatus: (id, cb) ->

    # deferred = new Promise
    # deploy.poll(100,10000000)

    # bar = new progress ':elapsed s [:curr/:stotal] [:bar] :percent [ ERRORS: :errors ] [ ETA: :eta s ]',
    #   complete:'='
    #   incomplete:' '
    #   width:20
    #   total:1000000
    @conn.metadata.checkDeployStatus id, true, (er, fullResult) =>
      
      if fullResult.done
        @deployCheckCB?(null, fullResult)
        cb?(null, @parseResult(fullResult))
      #   # if fullResult.success then print.pt Array::concat.call fullResult.details.componentSuccesses
      #   # else print.pt Array::concat.call fullResult.details.componentFailures
      else
        @checkStatus(id, cb)
        @deployCheckCB?(null, fullResult)

  getDeployOptions: ->
    if process.argv.indexOf('-m') is -1
      args = nopt(@sfDeployOpts, @shortHands)
      for key, value of args
        if @deployOptions[key]? then @deployOptions[key] = value

  deploy: (filterBy, cb) ->
    @filterBy = filterBy or @filterBy or []
    @getMetadata (er, data) =>

      @createFileList (er, files) =>
        @_deploy files, cb

  deployFileList: (filterBy, cb) ->
    @filterBy = filterBy or []
    @createFileList (er, files) =>
      @_deploy files, cb

  _deploy: (files, cb) ->
    
    @getDeployOptions()

    @files = files or @files


    metadataObjectsByDir = {}
    @metadata.metadataObjects.forEach (metadataObject) ->
      metadataObjectsByDir[metadataObject.directoryName] = metadataObject

    zip = new JSZip()
    packageMeta = {}


    # for fileName, data of @files when fileName.indexOf('package.xml') is -1

    #   zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName))
    #   (zip.file zipFileName, @files[fileName])  if @files[fileName]?
    #   noMeta = path.basename(zipFileName,'-meta.xml')

    #   fullName = path.basename(noMeta)
    #   fullName = path.basename(noMeta, path.extname(noMeta))
    #   typeDirName = path.basename(path.dirname(zipFileName))
    #   n = metadataObjectsByDir[typeDirName]?.xmlName
    #   if n?
    #     packageMeta[n] = packageMeta[n] || []

    #     if packageMeta[n].indexOf(fullName) is -1
    #       packageMeta[n].push fullName     
    #   zip.file zipFileName, data

    for fileName, data of @files when fileName.indexOf('package.xml') is -1

      if fileName.indexOf('-meta.xml') isnt -1
        noMeta = path.basename(fileName,'-meta.xml')
        fullName = path.basename(noMeta)
        fullName = path.basename(noMeta, path.extname(noMeta))
        zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName))
        typeDirName = path.basename(path.dirname(zipFileName))
        if fileName.indexOf('email/') isnt -1
          # typeDirName = path.basename(path.dirname(path.join(fileName, '../')))
          zipFileName = path.join("unpackaged/email", path.basename(path.resolve(fileName, "../")), path.basename(fileName))
          fullName = fileName.substring(fileName.indexOf('email/') + 6).replace('.email', '')
      else
        if fileName.indexOf('reports/') isnt -1 or fileName.indexOf('email/') isnt -1
          typeDirName = path.basename(path.dirname(path.join(fileName, '../')))
          zipFileName = path.join("unpackaged", typeDirName, path.basename(path.dirname(fileName)), path.basename(fileName))
          fullName = fileName.substring(fileName.indexOf(typeDirName + '/') + typeDirName.length + 1).replace('.report', '').replace('.email', '')

        else
          zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName))
          typeDirName = path.basename(path.dirname(zipFileName))
          fullName = path.basename(zipFileName, path.extname(zipFileName))

      n = metadataObjectsByDir[typeDirName]?.xmlName
      if n?
        packageMeta[n] = packageMeta[n] || []

        if packageMeta[n].indexOf(fullName) is -1
          packageMeta[n].push fullName

      zip.file zipFileName, data


    if @options.usePackageXml isnt true or @options.printPackageXml is true
      doc = xmldom.DOMImplementation::createDocument("http://soap.sforce.com/2006/04/metadata", "Package")
      E = (name, children) ->
        e = doc.createElement(name)
        i = 0

        while i < children.length
          e.appendChild children[i]
          i++
        e
      T = (name, text) ->
        e = doc.createElement(name)
        e.textContent = text
        e      
      
      doc.documentElement.setAttribute "xmlns", "http://soap.sforce.com/2006/04/metadata"
      doc.documentElement.appendChild T("version", @options.apiVersion)
      for key,value of packageMeta
        arr = []
        for val in value
          arr.push T('members', val)
        arr.push T('name', key)

        doc.documentElement.appendChild E("types", arr)

      xml = new xmldom.XMLSerializer().serializeToString(doc)
      zip.file "unpackaged/package.xml", xml
    else
      zip.file "unpackaged/package.xml", @files['src/package.xml']

    if @options.printPackageXml
      console.log(xml)
    else 
      @conn.metadata.pollTimeout = 100000


      z = zip.generate type: "nodebuffer"


      delete @deployOptions.runPackagedTestsOnly

      p = @conn.metadata.deploy z, @deployOptions
      p.check (er, asyncResult) =>
        if er? then return cb er

        if asyncResult? then @checkStatus asyncResult.id, cb


module.exports = SFDeploy
