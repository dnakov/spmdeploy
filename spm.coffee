process.title = "spm"
progress = require("progress")
print = require "node-print"
Promise = require("jsforce/lib/promise")
sflogin = require("./sflogin")
force = require("./sfdeploy")
fs = require("fs-extended")
path = require("path")
prompt = require("inquirer").prompt
log = require('better-log')

# sfJunitReporter = require("@spm/sf-junit-reporter")
# sfCloverReporter = require("@spm/sf-clover-reporter")
color = require('chalk')

class SPMDeploy
  bar: null
  basedir: process.cwd()

  constructor: ->
  
    @commands =
      "chooselogin": ->
        sflogin.chooseLogin (er, data) ->
          if er? then log er
          else log "Login Success"
          errorHandler()

      "sflogin": (options, cb) ->
        sflogin.login options, true, (er, conn) ->
          if er?
            log(er)
          else
            log("Login Success")
          cb(er, conn)

      "deploy": (options, callback) =>
        @deploy options, (er, result) =>
          if result.details.componentSuccesses? and result.details.componentFailures?
            res = Array::concat(result.details.componentSuccesses,result.details.componentFailures)
          else if result.details.componentFailures?
            res = result.details.componentFailures
          else
            res = result.details.componentSuccesses

          for item in res
            delete item.createdDate
            item.fileName = item.fileName.replace('unpackaged/', '')
            delete item.text
          print.pt res
          if options.fullLog
            console.log(JSON.stringify(result))
          if options.jUnit?
            filename = options.jUnit
            # junitReport = sfJunitReporter(result)
            # fs.createFile(path.join(@basedir, filename), junitReport)
          if options.clover?
            filename = options.clover
            # cloverReport = sfCloverReporter(result)
            # fs.createFile(path.join(@basedir, filename), cloverReport)
          # console.log res
          if result.success is false
            if result.details?.runTestResult?.codeCoverageWarnings?
              errorHandler(JSON.stringify(result.details?.runTestResult.codeCoverageWarnings))
            log('Deployment Failed')
          else
            log('Deployment Succeeded')

          callback(er, result)



  deploy: (options, cb) ->

    doDeploy = (options, conn, cb) =>
      dirs = []
      deploy = new force(@basedir, [options.filter], conn, options)
      deploy.getMetadata (er, data) =>
        deploy.createFileList (er, files) =>
          questions = []
          choices = []


          if options.manual
            for file of files when file.indexOf('-meta.xml') is -1
              choices.push
                name: file #.replace(/src\//g, "")
                value: file
            deploy.deployCheckCB = @deploymentProgress
            @createProgressBar(choices.length)
            deploy.deploy null, (er, result) ->
              cb?(null, result)
          else
            # files = files.sort();
            i = 0

            for file of files when file.indexOf('-meta.xml') is -1
              choices.push
                name: file #.replace(/src\//g, "")
                value: file
                type: "checkbox"
                checked: true
            for file of files when file.indexOf('-meta.xml') isnt -1
              if !files[file.replace('-meta.xml', '')]?
                choices.push
                  name: file #.replace(/src\//g, "")
                  value: file
                  type: "checkbox"
                  checked: true   
                                   
            questions.push
              name: "metadata"
              type: "checkbox"
              choices: choices
              message: "Select Files"

            prompt questions, (result) =>
              deploy.deployCheckCB = @deploymentProgress
              @createProgressBar(result.metadata.length)
              deploy.deploy result.metadata, (er, result) ->
                cb?(null, result) 

    
    if options.manual
      sflogin.manualLogin options, (er, conn) =>

        doDeploy options, conn, cb
    else 
      sflogin.chooseLogin options, (er, login) =>
        sflogin.login null, (er, conn) =>
          doDeploy options, conn, cb
          

  createProgressBar: (total) =>
    @bar = new progress ':elapsed s [:curr/:stotal] [:bar] :percent [ ERRORS: :errors ] [ ETA: :eta s ]',
      complete:'='
      incomplete:' '
      width:20
      total:total

  deploymentProgress: (er, result) =>
    @bar.total = if result.numberComponentsTotal > 0 then result.numberComponentsTotal else @bar.total

    # console.log(parseInt(result.numberComponentsDeployed) + parseInt(result.numberComponentErrors))
    tokens =
      stotal: @bar.total,
      errors:result.numberComponentErrors,
      curr:parseInt(result.numberComponentsDeployed) + parseInt(result.numberComponentErrors)

    ratio = tokens.curr / @bar.total

    @bar.update ratio, tokens unless @bar.curr / @bar.total is 1


module.exports = SPMDeploy
