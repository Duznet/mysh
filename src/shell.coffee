_ = require 'underscore'
readline = require 'readline'
parse = require('shell-quote').parse

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

  queue: []
  paused: false

  initCli: (options) ->
    @cli = readline.createInterface options
    @cli.setPrompt options.prompt

    @cli.on 'line', @onLine
    @cli.on 'pause', @onPause
    @cli.on 'resume', @onResume

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

  onLine: (line) =>
    if @options.debug
      console.log "got line: '#{line}'"
    @queue.push line
    if not @paused
      @processQueue()

  onPause: () =>
    @paused = true

  onResume: () =>
    @paused = false
    @processQueue()

  done: () =>
    @cli.resume()

  process: (line) ->
    parsedLine = parse line
    if @options.debug
      console.log 'parsed line:', parsedLine
    @done()

  processQueue: () ->
    if @queue.length isnt 0
      line = @queue.shift()
      if @options.debug
        console.log "processing line: '#{line}'"
      @cli.pause()
      @process line
    else
      @cli.prompt() if @options.terminal

module.exports = Shell
