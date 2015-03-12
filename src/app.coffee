program = require 'commander'

Shell = require './shell'

program
  .option '-d, --debug', 'debug mode'
  .parse process.argv

shell = new Shell {terminal: true, debug: program.debug}
shell.run()
