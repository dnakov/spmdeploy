fs = require("fs-extended")
async = require("async")
JSZip = require("jszip")
xmldom = require("xmldom")
path = require("path")
extend = require('util')._extend


# recursive('some/path', function (err, @files) {
#   // Files is an array of filename

# });


class SFDeploy

  rootPath: null
  currentDeployStatus: {}
  deployCheckCB: ->
  conn: null
  apiVersion: '31.0'
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



  constructor: (rootPath, filterBy, conn, apiVersion, options) ->
    @rootPath = rootPath
    @conn = conn
    @apiVersion = apiVersion
    @filterBy = filterBy
    @files = {}
    @dirs = []
    for key, val of options when key in @allowedDeployOptions
      v = val
      if val is "true" then v = true
      if val is "false" then v = false

      @deployOptions[key] = v
      console.log @deployOptions


  getMetadata: (cb) ->
    return cb?() unless @conn?
    @conn.metadata.describe @apiVersion
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
    @files = files or @files


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


    metadataObjectsByDir = {}
    @metadata.metadataObjects.forEach (metadataObject) ->
      metadataObjectsByDir[metadataObject.directoryName] = metadataObject

    zip = new JSZip()
    doc = xmldom.DOMImplementation::createDocument("http://soap.sforce.com/2006/04/metadata", "Package")
    doc.documentElement.setAttribute "xmlns", "http://soap.sforce.com/2006/04/metadata"

    for fileName, data of @files when fileName.indexOf("-meta.xml") is -1



      # throw "File not found: " + fileName unless files[fileName]?
      zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName))

      zip.file zipFileName, data

      (zip.file zipFileName + "-meta.xml", @files[fileName + "-meta.xml"])  if @files[fileName + "-meta.xml"]?
      fullName = path.basename(zipFileName, path.extname(zipFileName))
      typeDirName = path.basename(path.dirname(zipFileName))


      doc.documentElement.appendChild E("types", [
        T("members", fullName)
        T("name", metadataObjectsByDir[typeDirName]?.xmlName)
      ])

    doc.documentElement.appendChild T("version", @apiVersion)
    xml = new xmldom.XMLSerializer().serializeToString(doc)

    zip.file "unpackaged/package.xml", xml


    @conn.metadata.pollTimeout = 100000


    z = zip.generate type: "nodebuffer"


    delete @deployOptions.runPackagedTestsOnly

    p = @conn.metadata.deploy z, @deployOptions
    p.check (er, asyncResult) =>
      if er? then return cb er

      if asyncResult? then @checkStatus asyncResult.id, cb


module.exports = SFDeploy
