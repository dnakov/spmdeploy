jsforce = require("jsforce")
q = require("q")
fs = require("graceful-fs")
iprompt = require("inquirer").prompt
path = require("path")
keytar = require "keytar"
color = require "cli-color"
basedir = process.cwd()

class SFLogin
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


      fs.readFile @passFile, "utf8", (er, data) =>

        lst = if data? then JSON.parse(data) else {sfdc:{}}
        hash = @params.loginUrl + '$' + @params.username
        if keytar.getPassword('SPM-SFDC: ' + @params.loginUrl, @params.username) is null
          keytar.addPassword 'SPM-SFDC: ' + @params.loginUrl, @params.username, @params.password
        else
          keytar.replacePassword('SPM-SFDC: ' + @params.loginUrl, @params.username, @params.password)
        lst.sfdc[hash] =
          lastMod: new Date()
          username: @params.username
          loginUrl: @params.loginUrl
          apiVersion: @params.apiVersion
        @activeLogin =
          lastMod: new Date()
          username: @params.username
          loginUrl: @params.loginUrl
          apiVersion: @params.apiVersion
          password: keytar.getPassword('SPM-SFDC: ' + @params.loginUrl, @params.username)
        @writeFile @passFile, JSON.stringify(lst), "utf8", (er, success) =>
        cb?()

  chooseLogin: (cb) ->
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
        @activeLogin =
          loginUrl: answer.login.loginUrl
          username: answer.login.username
          apiVersion: answer.login.apiVersion
          password: keytar.getPassword('SPM-SFDC: ' + answer.login.loginUrl, answer.login.username)
        cb?()


  login: (reinit, cb) ->
    if reinit isnt true or @activeLogin?
      @_login cb
    else
      @initLogin (data) =>
        @_login (er, data) =>
          cb? er if er?
          cb? null, data

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
      console.log arguments
      return cb?(er) if er?

      cb?(null, conn)

        # cb(err)

module.exports = new SFLogin


