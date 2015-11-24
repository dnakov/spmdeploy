#!/usr/bin/env node
	program = require("commander")
	var SPM = require('../spm')
	var spm = new SPM()

	// program
	// 	.option('-m, --manual', 'true')
 //    .option('--printPackageXml, --printPackageXml', 'true')
 //    .option('--checkOnly, --checkOnly', 'true')
 //    .option('--ignoreWarnings, --ignoreWarnings', 'true')
 //    .option('--performRetrieve, --performRetrieve', 'true')
 //    .option('--purgeOnDelete, --purgeOnDelete', 'true')
 //    .option('--rollbackOnError, --rollbackOnError', 'true')
 //    .option('--runAllTests, --runAllTests', 'true')
 //    .option('--runTests, --runTests', 'true')
 //    .option('--singlePackage, --singlePackage', 'true')
 //    .option('--allowMissingFiles, --allowMissingFiles', 'true')
 //    .option('--autoUpdatePackage, --autoUpdatePackage', 'true')
 //    .option('--runPackagedTestsOnly, --runPackagedTestsOnly', 'true')
 //    .option('--useDefaultMetadata, --useDefaultMetadata', 'true')
 //    .option('--usePackageXml, --usePackageXml [usePackageXml]', 'true')
 //    .option('--apiVersion, --apiVersion [apiVersion]', 'true', '33.0')
 //    .option('-u, --username [username]', 'true', '')
 //    .option('-p, --password [password]', 'true', '')
 //    .option('-url, --loginUrl [loginUrl]', 'true', 'https://login.salesforce.com')
 //    .option('-f, --filter [value]', 'true')	

  program
    .command('sflogin')    
    .description('login to salesforce')
    .option('-m, --manual', 'no prompts, expects options to be passed in')
    .option('--apiVersion, --apiVersion [apiVersion]', 'api version', '33.0')
    .option('-u, --username [username]', 'username', '')
    .option('-p, --password [password]', 'password', '')
    .option('-url, --loginUrl [loginUrl]', 'login url', 'https://login.salesforce.com')
    .action(function(options) {
    	spm.commands.sflogin(options, function(er, conn) {
    		if(er != null) process.exit(1)
    	})
    })

  program    
    .command('deploy')
    .description('asks for what to deploy, where and then deploys')
		.option('-m, --manual', 'no prompts, expects options to be passed in')
    .option('--printPackageXml, --printPackageXml', 'generates a package.xml from existing folders')
    .option('--checkOnly, --checkOnly', 'read sf docs')
    .option('--ignoreWarnings, --ignoreWarnings', 'read sf docs')
    .option('--performRetrieve, --performRetrieve', 'read sf docs')
    .option('--purgeOnDelete, --purgeOnDelete', 'read sf docs')
    .option('--rollbackOnError, --rollbackOnError', 'read sf docs')
    .option('--runAllTests, --runAllTests', 'read sf docs')
    .option('--runTests, --runTests', 'read sf docs')
    .option('--singlePackage, --singlePackage', 'read sf docs')
    .option('--allowMissingFiles, --allowMissingFiles', 'read sf docs')
    .option('--autoUpdatePackage, --autoUpdatePackage', 'read sf docs')
    .option('--runPackagedTestsOnly, --runPackagedTestsOnly', 'read sf docs')
    .option('--useDefaultMetadata, --useDefaultMetadata', 'doesnt ask the server for metadata')
    .option('--usePackageXml, --usePackageXml [usePackageXml]', 'specify existing package.xml file [usePackageXml]')
    .option('--apiVersion, --apiVersion [apiVersion]', 'api version', '33.0')
    .option('-u, --username [username]', 'username', '')
    .option('-p, --password [password]', 'password', '')
    .option('-url, --loginUrl [loginUrl]', 'login url', 'https://login.salesforce.com')
    .option('-f, --filter [value]', 'regex filter for files to deploy')	    
    .option('--checkInterval, --checkInterval <checkInterval>', 'deploy check interval', 2000)
    .action(function(options) {
    	spm.commands.deploy(options, function(er, results) {
    		if(er != null) process.exit(1)
    	})
    })

  
    // .action(function(cmd, options) {
    // 	spm.commands.deploy(options)
    // })
  if (!process.argv.slice(2).length) {
    program.outputHelp();
  }

  program.parse(process.argv);    