sfdeploy = require("../index")
jsforce = require("jsforce")
assert = require("assert")

describe "Deploy", ->
  this.timeout(160000);

  describe '#readMetadata()', ->
    this.timeout(140000);
    it 'should connect to sf and filter to classes/test3.cls only', (done) ->
      conn = new jsforce.Connection(
        loginUrl: 'https://login.salesforce.com'
        version: '31.0'
      )

      conn.login 'daniel@3demo.com', 'dgdfee12345', (er, data) =>
        deploy = new sfdeploy(__dirname, ['test3'], conn, '31.0')
        deploy.getMetadata (er, data) ->
          deploy.createFileList (er, files) ->
            console.log files
            assert.equal(Object.keys(files).length, 1)
            assert.equal(true, Object.keys(files)[0].indexOf('test3') != -1 )
            done()

  describe '#readFiles()', ->
    it 'should find test3 file but not test4', (done) =>
      deploy = new sfdeploy(__dirname, ['test3'])
      deploy.createFileList (er, files) ->
        console.log(files)
        assert.equal(Object.keys(files).length, 1)
        assert.equal(true, Object.keys(files)[0].indexOf('test3') != -1 )
        done()

  describe '#deploy()', ->
    it 'should deploy some junk', (done) ->
      conn = new jsforce.Connection(
          loginUrl: 'https://login.salesforce.com'
          version: '31.0'
        )

      conn.login 'daniel@3demo.com', 'dgdfee12345', (er, data) =>
        deploy = new sfdeploy(__dirname, [], conn, '31.0')
        deploy.deploy [], (er, data) ->
          done()

