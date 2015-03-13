program = require 'commander'

Shell = require './shell'

program
  .option '-d, --debug', 'debug mode'
  .option '-p, --parseInfo', 'parse info'
  .option '-l, --lineInfo', 'line info'
  .parse process.argv

options =
  terminal: true
  debug: program.debug
  parseInfo: program.parseInfo
  lineInfo: program.lineInfo

shell = new Shell options
shell.run()
