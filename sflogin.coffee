jsforce = require("jsforce")
Promise = require("jsforce/lib/promise")
q = require("q")
fs = require("graceful-fs")
iprompt = require("inquirer").prompt
path = require("path")
try
  keytar = require "keytar"
catch error
crypto = require "crypto"
color = require "cli-color"
basedir = process.cwd()

class SFLogin
  knownOpts: 
    username: String
    password: String
    "api-version": String
    "login-url": String
  shortHands: {}

  passFile: path.resolve(process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE, "spm.json")
  prompt: (questions) ->
    d = q.defer()
    iprompt questions, (answers) ->
      d.resolve(answers)
    d.promise
  constructor: ->
    @readFile = q.denodeify fs.readFile
    @writeFile = q.denodeify fs.writeFile

  initLogin: (cb) ->
    questions = [
      {
        name: "username"
        message: "SF Username: "
      }
      {
        name: "password"
        message: "SF Password: "
        type:'password'
      }
      {
        name: "apiVersion"
        message: "API Version: "
        default: "30.0"
      }
      {
        name: "loginUrl"
        type: "list"
        choices: [
          {
            name: "Developer/Production"
            value: "https://login.salesforce.com"
          }
          {
            name: "Sandbox"
            value: "https://test.salesforce.com"
          }
        ]
        message: "Org Type"
        default:
          name: "Developer/Production"
          value: "https://login.salesforce.com"
      }
    ]
    iprompt questions, (params) =>
      @params = params
      isdone = {};
      cipher = crypto.createCipher('aes256', 'NJzdDqqiDUWsQFwLGoRiTHUPcXVWirjUYTgUTsL7BtMZ3jvgDB') 
      encrypted = if @params.password? then cipher.update(@params.password, 'utf8', 'hex') + cipher.final('hex') else null

      fs.readFile @passFile, "utf8", (er, data) =>

        lst = if data? then JSON.parse(data) else {sfdc:{}}
        hash = @params.loginUrl + '$' + @params.username
        if keytar?.getPassword('SPM-SFDC: ' + @params.loginUrl, @params.username) is null
          keytar?.addPassword 'SPM-SFDC: ' + @params.loginUrl, @params.username, @params.password
        else
          keytar?.replacePassword('SPM-SFDC: ' + @params.loginUrl, @params.username, @params.password)
        lst.sfdc[hash] =
          lastMod: new Date()
          username: @params.username
          loginUrl: @params.loginUrl
          apiVersion: @params.apiVersion
          password: encrypted
        @activeLogin =
          lastMod: new Date()
          username: @params.username
          loginUrl: @params.loginUrl
          apiVersion: @params.apiVersion
          password: @params.password
        @writeFile @passFile, JSON.stringify(lst), "utf8", (er, success) =>
        cb?()

  chooseLogin: (options, cb) -> 
    fs.readFile @passFile, 'utf-8', (er, data) =>
      lst = JSON.parse(data)
      choices = []
      for key,value of lst.sfdc
        choices.push
          value:value
          name:value.username + ' | ' + color.blue(value.loginUrl)
          dt:value
      choices.sort (a,b) ->
        date1 = new Date(a.lastMod)
        date2 = new Date(b.lastMod)
        if date1 > date2 then return -1
        if date1 < date2 then return 1
        return 0
      questions =
        name: 'login'
        type:'list'
        choices: choices
        message: 'Select Login: '
      iprompt questions, (answer) =>
        if keytar?
          pass = keytar?.getPassword('SPM-SFDC: ' + answer.login.loginUrl, answer.login.username)
        else
          decipher = crypto.createDecipher('aes256', 'NJzdDqqiDUWsQFwLGoRiTHUPcXVWirjUYTgUTsL7BtMZ3jvgDB')
          pass = if answer.login.password? then decipher.update(answer.login.password, 'hex', 'utf8') + decipher.final('utf8') else null

        @activeLogin =
          loginUrl: answer.login.loginUrl
          username: answer.login.username
          apiVersion: answer.login.apiVersion
          password: pass
        cb?(null, @activeLogin)

  manualLogin: (options, cb) ->
    @activeLogin =
      username: options.username
      password: options.password
      loginUrl: options.loginUrl
      apiVersion: options.apiVersion
    @login(options, true, cb)

  login: (options, reinit, cb) ->
    if reinit isnt true or @activeLogin?
      @_login (er, data) =>
        cb?(null, data)
    else
      @initLogin (data) =>
        @_login (er, data) =>
          return cb? er if er?
          return cb? null, data

  _login: (cb) ->
    # return Promise.all([
    #   q.nfcall(fs.readFile, "spm.json", "utf-8")
    #   q.nfcall(fs.readFile, (process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE) + "/spm.json", "utf-8")
    # ]).then (files) ->
    throw "Missing loginUrl"  unless @activeLogin.loginUrl
    throw "Missing username"  unless @activeLogin.username
    throw "Missing password"  unless @activeLogin.password
    throw "Missing apiVersion"  unless @activeLogin.apiVersion
    conn = new jsforce.Connection(
      loginUrl: @activeLogin.loginUrl
      version: @activeLogin.apiVersion
    )

    conn.login @activeLogin.username, @activeLogin.password, (er, conn2) ->
      return cb?(er) if er?

      cb?(null, conn)

        # cb(err)

module.exports = new SFLogin


