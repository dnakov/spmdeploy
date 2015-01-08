fs = require("fs-extended")
async = require("async")
JSZip = require("jszip")
xmldom = require("xmldom")
sflogin = require("./sflogin")
path = require("path")



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
  deployOptions:
    # checkOnly:false
    # ignoreWarnings:false
    # performRetrieve:false
    # purgeOnDelete:false
    rollbackOnError:false
    runAllTests:false
    # runTests:[]
    # singlePackage:true
    # allowMissingFiles:true
    # autoUpdatePackage:false



  constructor: (rootPath, filterBy, conn, apiVersion) ->
    @rootPath = rootPath
    @conn = conn
    @apiVersion = apiVersion
    @filterBy = filterBy
    @files = {}
    @dirs = []


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

    if (match? and match.length > 1) and (@dirs.length == 0 or match[1] in @dirs)

      return true unless @filterBy.length > 0
      i = 0

      while i < @filterBy.length
        item = @filterBy[i]
        re = new RegExp(item)
        return true if re.test(itemPath)
        i++

    return false

  createFileList: (cb) ->
    @files = {}
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
        cb? null, @files



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
        @deployCheckCB?(fullResult)
        cb?(fullResult)
      #   # if fullResult.success then print.pt Array::concat.call fullResult.details.componentSuccesses
      #   # else print.pt Array::concat.call fullResult.details.componentFailures
      else
        @checkStatus(id, cb)
        @deployCheckCB?(fullResult)

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

      console.log(fileName)

      # throw "File not found: " + fileName unless files[fileName]?
      zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName))

      zip.file zipFileName, data

      (zip.file zipFileName + "-meta.xml", @files[fileName + "-meta.xml"])  if @files[fileName + "-meta.xml"]?
      fullName = path.basename(zipFileName, path.extname(zipFileName))
      typeDirName = path.basename(path.dirname(zipFileName))


      doc.documentElement.appendChild E("types", [
        T("members", fullName)
        T("name", metadataObjectsByDir[typeDirName].xmlName)
      ])

    doc.documentElement.appendChild T("version", @apiVersion)
    xml = new xmldom.XMLSerializer().serializeToString(doc)

    zip.file "unpackaged/package.xml", xml


    @conn.metadata.pollTimeout = 100000


    z = zip.generate type: "nodebuffer"

    console.log @conn
    p = @conn.metadata.deploy z, @deployOptions
    p.check (er, asyncResult) =>
      if asyncResult?
        @checkStatus asyncResult.id, cb
      else
        console.log er
        # console.log 'done'
        # cb?()

    # p.complete (asyncResult) ->
      # console.log arguments
    # .complete (er, data) ->
      # console.log arguments
      # @currentDeployStatus = result
      # @checkStatus()



#    @checkStatus()

    # p.check().then() ->
    # p.check().then (asyncResult) ->

    # p.complete (er, data) ->

      # print.pt deployResult.details.componentSuccesses

      # cb? er, data

    # updateStatus(conn,p)


module.exports = SFDeploy
