_ = require 'underscore'
readline = require 'readline'

class Shell

  defaults:
    terminal: false
    prompt: 'mysh> '
    input: process.stdin
    output: process.stdout
    locals: {}
    env: process.env
    debug: false

  options: {}

  initCli: (options) ->
    @cli = readline.createInterface options
    @cli.setPrompt options.prompt

    @cli.on 'line', (line) =>
      if @options.debug
        console.log "got line: '#{line}'"
      if @options.terminal then @cli.prompt()

  constructor: (options = {}) ->
    @options = _.defaults options, @defaults

    cliOptions =
      input: @options.input
      output: @options.output
      terminal: @options.terminal
      prompt: @options.prompt

    @initCli cliOptions

  run: ->
    if @options.terminal then @cli.prompt()


module.exports = Shell
