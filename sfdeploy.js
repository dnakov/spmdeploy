// Generated by CoffeeScript 1.8.0
var JSZip, SFDeploy, async, extend, fs, nopt, path, xmldom,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

fs = require("fs-extended");

async = require("async");

JSZip = require("jszip");

xmldom = require("xmldom");

path = require("path");

extend = require('util')._extend;

nopt = require("nopt");

SFDeploy = (function() {
  SFDeploy.prototype.sfDeployOpts = {
    'checkOnly': Boolean,
    'ignoreWarnings': Boolean,
    'performRetrieve': Boolean,
    'purgeOnDelete': Boolean,
    'rollbackOnError': Boolean,
    'runAllTests': Boolean,
    'runTests': Boolean,
    'singlePackage': Boolean,
    'allowMissingFiles': Boolean,
    'autoUpdatePackage': Boolean,
    'runPackagedTestsOnly': Boolean,
    'useDefaultMetadata': Boolean,
    'usePackageXml': Boolean,
    'apiVersion': String,
    'filter': [String, Array]
  };

  SFDeploy.prototype.shortHands = {};

  SFDeploy.prototype.rootPath = null;

  SFDeploy.prototype.currentDeployStatus = {};

  SFDeploy.prototype.options = {};

  SFDeploy.prototype.deployCheckCB = function() {};

  SFDeploy.prototype.conn = null;

  SFDeploy.prototype.metadata = {
    metadataObjects: []
  };

  SFDeploy.prototype.filterBy = [];

  SFDeploy.prototype.files = {};

  SFDeploy.prototype.dirs = [];

  SFDeploy.prototype.testFiles = [];

  SFDeploy.prototype.allowedDeployOptions = ['checkOnly', 'ignoreWarnings', 'performRetrieve', 'purgeOnDelete', 'rollbackOnError', 'runAllTests', 'runTests', 'singlePackage', 'allowMissingFiles', 'autoUpdatePackage', 'runPackagedTestsOnly'];

  SFDeploy.prototype.deployOptions = {
    rollbackOnError: false,
    runAllTests: false,
    runTests: []
  };

  SFDeploy.prototype.showAllText = false;

  function SFDeploy(rootPath, filterByOld, conn, options) {
    this.pathFilter = __bind(this.pathFilter, this);
    var key, v, val;
    this.rootPath = rootPath;
    this.conn = conn;
    this.filterBy = Array.prototype.concat([], options.filter) || filterBy;
    this.files = {};
    this.dirs = [];
    this.options = options || nopt(this.sfDeployOpts, this.shortHands);
    for (key in options) {
      val = options[key];
      if (!(__indexOf.call(this.allowedDeployOptions, key) >= 0)) {
        continue;
      }
      v = val;
      if (val === "true") {
        v = true;
      }
      if (val === "false") {
        v = false;
      }
      this.deployOptions[key] = v;
    }
    if (this.options.apiVersion == null) {
      this.options.apiVersion = '33.0';
    }
  }

  SFDeploy.prototype.packagexml = function(cb) {
    this.options.printPackageXml = true;
    this.options.useDefaultMetadata = true;
    return this.deploy();
  };

  SFDeploy.prototype.getMetadata = function(cb) {
    if (this.options.useDefaultMetadata === true) {
      this.metadata = require("@spm/sf-default-metadata");
      this.getMetaDirs();
      return cb(null, this.metadata);
    } else {
      if (this.conn == null) {
        return typeof cb === "function" ? cb('blah') : void 0;
      }
      return this.conn.metadata.describe(this.options.apiVersion).then((function(_this) {
        return function(meta) {
          _this.metadata = meta;
          _this.getMetaDirs();
          return typeof cb === "function" ? cb(null, meta) : void 0;
        };
      })(this), function(err) {
        return typeof cb === "function" ? cb(err) : void 0;
      });
    }
  };

  SFDeploy.prototype.getMetaDirs = function() {
    var dir, _i, _len, _ref, _results;
    this.dirs = [];
    _ref = this.metadata.metadataObjects;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      dir = _ref[_i];
      _results.push(this.dirs.push(dir.directoryName));
    }
    return _results;
  };

  SFDeploy.prototype.pathFilter = function(itemPath) {
    var i, item, match, re, _ref;
    match = itemPath.match(/src\/(.*?)\//);
    if (itemPath.indexOf('src/package.xml') !== -1) {
      return this.options.usePackageXml;
    }
    if (((match != null) && match.length > 1 && (_ref = match[1], __indexOf.call(this.dirs, _ref) >= 0)) || this.dirs.length === 0) {
      if (!(this.filterBy.length > 0)) {
        return true;
      }
      i = 0;
      while (i < this.filterBy.length) {
        item = this.filterBy[i];
        re = new RegExp(item);
        if (re.test(itemPath)) {
          return true;
        }
        i++;
      }
    }
    return false;
  };

  SFDeploy.prototype.createFileList = function(cb) {
    var areadFile;
    areadFile = (function(_this) {
      return function(item, cb) {
        return fs.readFile(path.join(_this.rootPath, item), {
          flag: "r"
        }, function(er, results) {
          return cb(er, results);
        });
      };
    })(this);
    return fs.listFiles(path.resolve(this.rootPath), {
      filter: this.pathFilter,
      recursive: 1
    }, (function(_this) {
      return function(err, files) {
        return async.map(files, areadFile, function(er, results) {
          var data, i, _i, _len;
          for (i = _i = 0, _len = results.length; _i < _len; i = ++_i) {
            data = results[i];
            _this.files[files[i]] = data;
            if (_this.deployOptions.runPackagedTestsOnly) {
              if (data.toString('utf8').indexOf('@isTest') !== -1) {
                _this.deployOptions.runTests.push(files[i].match(/[^\/]*(?=\.[^.]+($|\?))/)[0]);
              }
            }
          }
          return typeof cb === "function" ? cb(null, _this.files, _this.testFiles) : void 0;
        });
      };
    })(this));
  };

  SFDeploy.prototype.getTextFiles = function() {
    var data, key, textFiles, _ref;
    textFiles = {};
    _ref = this.files;
    for (key in _ref) {
      data = _ref[key];
      textFiles[key] = {
        text: data.toString('utf-8')
      };
    }
    return textFiles;
  };

  SFDeploy.prototype.parseResult = function(result) {
    var components, data, item, key, parsed, total, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
    if (result == null) {
      return null;
    }
    parsed = result;
    parsed.createdDate = new Date(parsed.createdDate);
    parsed.lastModifiedDate = new Date(parsed.lastModifiedDate);
    parsed.startDate = new Date(parsed.startDate);
    parsed.completedDate = new Date(parsed.completedDate);
    parsed.files = {};
    if (result.details == null) {
      return parsed;
    }
    components = Array.prototype.concat((_ref = result.details) != null ? _ref.componentSuccesses : void 0, (_ref1 = result.details) != null ? _ref1.componentFailures : void 0);
    total = {
      locations: 0,
      notCovered: 0,
      percentage: 0,
      num: 0
    };
    for (_i = 0, _len = components.length; _i < _len; _i++) {
      item = components[_i];
      if (item != null) {
        _ref2 = this.files;
        for (key in _ref2) {
          data = _ref2[key];
          if (!(key.indexOf(item.fileName.replace('unpackaged/', '')) !== -1)) {
            continue;
          }
          parsed.files[key] = extend(item);
          if (this.showAllText || key.indexOf('.cls') !== -1 || key.indexOf('.trigger') !== -1) {
            parsed.files[key].text = data.toString('utf-8');
          }
          parsed.files[key].createdDate = new Date(parsed.files[key].createdDate);
          break;
        }
      }
    }
    if (((_ref3 = result.details.runTestResult) != null ? _ref3.codeCoverage : void 0) == null) {
      return parsed;
    }
    _ref5 = (_ref4 = result.details.runTestResult) != null ? _ref4.codeCoverage : void 0;
    for (_j = 0, _len1 = _ref5.length; _j < _len1; _j++) {
      item = _ref5[_j];
      if (item.type === 'Class') {
        _ref6 = this.files;
        for (key in _ref6) {
          data = _ref6[key];
          if (!(key.indexOf('classes/' + item.name + '.cls') >= 0)) {
            continue;
          }
          if (parsed.files[key] == null) {
            break;
          }
          parsed.files[key].testResults = extend(item);
          parsed.files[key].testResults.locationsNotCovered = Array.prototype.concat(parsed.files[key].testResults.locationsNotCovered);
          if (item.numLocations === null || item.numLocationsNotCovered === null) {
            break;
          }
          parsed.files[key].testResults.coveragePercentage = 100 * (parseInt(item.numLocations) - parseInt(item.numLocationsNotCovered)) / parseInt(item.numLocations);
          total.locations += parseInt(item.numLocations);
          total.notCovered += parseInt(item.numLocationsNotCovered);
          total.num++;
          console.log(total);
          break;
        }
      }
      if (item.type === 'Trigger') {
        _ref7 = this.files;
        for (key in _ref7) {
          data = _ref7[key];
          if (!(key.indexOf('triggers/' + item.name + '.trigger') >= 0)) {
            continue;
          }
          if (parsed.files[key] == null) {
            break;
          }
          parsed.files[key].testResults = extend(item);
          if (item.numLocations === null || item.numLocationsNotCovered === null) {
            break;
          }
          parsed.files[key].testResults.coveragePercentage = 100 * (parseInt(item.numLocations) - parseInt(item.numLocationsNotCovered)) / parseInt(item.numLocations);
          total.locations += parseInt(item.numLocations);
          total.notCovered += parseInt(item.numLocationsNotCovered);
          total.num++;
          break;
        }
      }
    }
    parsed.totalCoverage = total.num === 0 ? 0 : total.locations - total.notCovered / total.num;
    return parsed;
  };

  SFDeploy.prototype.checkStatus = function(id, cb) {
    return this.conn.metadata.checkDeployStatus(id, true, (function(_this) {
      return function(er, fullResult) {
        if (fullResult.done) {
          if (typeof _this.deployCheckCB === "function") {
            _this.deployCheckCB(null, fullResult);
          }
          return typeof cb === "function" ? cb(null, _this.parseResult(fullResult)) : void 0;
        } else {
          _this.checkStatus(id, cb);
          return typeof _this.deployCheckCB === "function" ? _this.deployCheckCB(null, fullResult) : void 0;
        }
      };
    })(this));
  };

  SFDeploy.prototype.getDeployOptions = function() {
    var args, key, value, _results;
    if (process.argv.indexOf('-m') === -1) {
      args = nopt(this.sfDeployOpts, this.shortHands);
      _results = [];
      for (key in args) {
        value = args[key];
        if (this.deployOptions[key] != null) {
          _results.push(this.deployOptions[key] = value);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    }
  };

  SFDeploy.prototype.deploy = function(filterBy, cb) {
    this.filterBy = filterBy || this.filterBy || [];
    return this.getMetadata((function(_this) {
      return function(er, data) {
        return _this.createFileList(function(er, files) {
          return _this._deploy(files, cb);
        });
      };
    })(this));
  };

  SFDeploy.prototype.deployFileList = function(filterBy, cb) {
    this.filterBy = filterBy || [];
    return this.createFileList((function(_this) {
      return function(er, files) {
        return _this._deploy(files, cb);
      };
    })(this));
  };

  SFDeploy.prototype._deploy = function(files, cb) {
    var E, T, arr, data, doc, fileName, fullName, key, metadataObjectsByDir, n, noMeta, p, packageMeta, typeDirName, val, value, xml, z, zip, zipFileName, _i, _len, _ref, _ref1;
    this.getDeployOptions();
    this.files = files || this.files;
    metadataObjectsByDir = {};
    this.metadata.metadataObjects.forEach(function(metadataObject) {
      return metadataObjectsByDir[metadataObject.directoryName] = metadataObject;
    });
    zip = new JSZip();
    packageMeta = {};
    _ref = this.files;
    for (fileName in _ref) {
      data = _ref[fileName];
      if (!(fileName.indexOf('package.xml') === -1)) {
        continue;
      }
      if (fileName.indexOf('-meta.xml') !== -1) {
        noMeta = path.basename(fileName, '-meta.xml');
        fullName = path.basename(noMeta);
        fullName = path.basename(noMeta, path.extname(noMeta));
        zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName));
        typeDirName = path.basename(path.dirname(zipFileName));
        if (fileName.indexOf('email/') !== -1) {
          zipFileName = path.join("unpackaged/email", path.basename(path.resolve(fileName, "../")), path.basename(fileName));
          fullName = fileName.substring(fileName.indexOf('email/') + 6).replace('.email', '');
        }
      } else {
        if (fileName.indexOf('reports/') !== -1 || fileName.indexOf('email/') !== -1) {
          typeDirName = path.basename(path.dirname(path.join(fileName, '../')));
          zipFileName = path.join("unpackaged", typeDirName, path.basename(path.dirname(fileName)), path.basename(fileName));
          fullName = fileName.substring(fileName.indexOf(typeDirName + '/') + typeDirName.length + 1).replace('.report', '').replace('.email', '');
        } else {
          zipFileName = path.join("unpackaged", path.basename(path.resolve(fileName, "../")), path.basename(fileName));
          typeDirName = path.basename(path.dirname(zipFileName));
          fullName = path.basename(zipFileName, path.extname(zipFileName));
        }
      }
      n = (_ref1 = metadataObjectsByDir[typeDirName]) != null ? _ref1.xmlName : void 0;
      if (n != null) {
        packageMeta[n] = packageMeta[n] || [];
        if (packageMeta[n].indexOf(fullName) === -1) {
          packageMeta[n].push(fullName);
        }
      }
      zip.file(zipFileName, data);
    }
    if (this.options.usePackageXml !== true || this.options.printPackageXml === true) {
      doc = xmldom.DOMImplementation.prototype.createDocument("http://soap.sforce.com/2006/04/metadata", "Package");
      E = function(name, children) {
        var e, i;
        e = doc.createElement(name);
        i = 0;
        while (i < children.length) {
          e.appendChild(children[i]);
          i++;
        }
        return e;
      };
      T = function(name, text) {
        var e;
        e = doc.createElement(name);
        e.textContent = text;
        return e;
      };
      doc.documentElement.setAttribute("xmlns", "http://soap.sforce.com/2006/04/metadata");
      doc.documentElement.appendChild(T("version", this.options.apiVersion));
      for (key in packageMeta) {
        value = packageMeta[key];
        arr = [];
        for (_i = 0, _len = value.length; _i < _len; _i++) {
          val = value[_i];
          arr.push(T('members', val));
        }
        arr.push(T('name', key));
        doc.documentElement.appendChild(E("types", arr));
      }
      xml = new xmldom.XMLSerializer().serializeToString(doc);
      zip.file("unpackaged/package.xml", xml);
    } else {
      zip.file("unpackaged/package.xml", this.files['src/package.xml']);
    }
    if (this.options.printPackageXml) {
      return console.log(xml);
    } else {
      this.conn.metadata.pollTimeout = 100000;
      z = zip.generate({
        type: "nodebuffer"
      });
      delete this.deployOptions.runPackagedTestsOnly;
      p = this.conn.metadata.deploy(z, this.deployOptions);
      return p.check((function(_this) {
        return function(er, asyncResult) {
          if (er != null) {
            return cb(er);
          }
          if (asyncResult != null) {
            return _this.checkStatus(asyncResult.id, cb);
          }
        };
      })(this));
    }
  };

  return SFDeploy;

})();

module.exports = SFDeploy;
