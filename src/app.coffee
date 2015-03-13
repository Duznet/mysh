program = require 'commander'

Shell = require './shell'

program
  .option '-d, --debug', 'debug mode'
  .option '-p, --parseOnly', 'parse only mode'
  .parse process.argv

shell = new Shell {terminal: true, debug: program.debug, parseOnly: program.parseOnly}
shell.run()
