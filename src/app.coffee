program = require 'commander'

Shell = require './shell'

program
  .option '-d, --debug', 'debug mode'
  .option '-p, --parseInfo', 'parse info'
  .option '-l, --lineInfo', 'line info'
  .option '-n, --nonTerminal', 'non terminal mode'
  .parse process.argv

options =
  terminal: true and not program.nonTerminal
  debug: program.debug
  parseInfo: program.parseInfo
  lineInfo: program.lineInfo

shell = new Shell options
shell.run()
