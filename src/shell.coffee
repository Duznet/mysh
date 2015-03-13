_ = require 'underscore'
readline = require 'readline'
parse = require('shell-quote').parse
fs = require 'fs'
childProcess = require 'child_process'
EventEmitter = require('events').EventEmitter

class Shell extends EventEmitter

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
  isPaused: false
  isClosed: false

  initCli: (options) ->
    @cli = readline.createInterface options
    @cli.setPrompt options.prompt

    @cli.on 'line', @onLine
    @cli.on 'pause', @onPause
    @cli.on 'resume', @onResume
    @cli.on 'close', @onClose

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
      console.log "got: '#{line}'"
    @queue.push line
    if not @isPaused
      @processQueue()

  onPause: () =>
    @isPaused = true

  onResume: () =>
    @isPaused = false
    @processQueue()

  onClose: () =>
    @isClosed = true

  done: () =>
    if @options.debug
      console.log 'done'
    @cli.resume()

  commands:

    pwd: (done) ->
      console.log process.cwd()
      done()

    cd: (done, dir) ->
      process.chdir dir
      done()

    ls: (done, path = process.cwd()) ->
      fs.readdir path, (err, files) ->
        result = ''
        for file in files
          result += file + '\t'
        console.log result
        done()

    run: (done, args...) ->
      childCmd = args[0]
      childArgs = _.rest args
      spawned = childProcess.spawn childCmd, childArgs, {env: @options.env, stdio: 'inherit'}
      spawned.on 'exit', (code) ->
        done()
      spawned.on 'error', (err) ->
        console.log "could not run command: '#{childCmd}'"
        done()

    source: (done, path) ->
      options = @options
      options.input = fs.createReadStream path
      options.output = process.stdout
      options.terminal = false

      childShell = new Shell options
      childShell.on 'finish', () =>
        done()

    env: (done) ->
      for k, v of @options.env
        console.log "#{k}=#{v}"
      done()

    set: (done, line) ->
      data = line.split '='
      varName = data[0]
      value = data[1]
      if @options.env[varName]?
        @options.env[varName] = value
      else
        @options.locals[varName] = value
      done()

    export: (done, line) ->
      data = line.split '='
      if data.length is 2
        @options.env[data[0]] = data[1]
      else
        @options.env[data[0]] = @options.locals[data[0]]
      done()

    echo: (done, args...) ->
      result = ''
      _.each args, (arg) -> result += arg + ' '
      console.log result
      done()


  process: (line) ->
    parsed = parse line, _.extend(@options.locals, @options.env)
    if @options.debug
      console.log 'parsed:', parsed
    if parsed.length is 0
      @done()
      return
    cmd = ''
    args = []
    if @commands[parsed[0]]?
      cmd = parsed[0]
      args = _.rest parsed
    else
      cmd = 'run'
      args = parsed

    @commands[cmd].apply this, [@done].concat(args)

  processQueue: () ->
    if @queue.length isnt 0
      line = @queue.shift()
      if @options.debug
        console.log "processing: '#{line}'"
      @cli.pause()
      @process line
    else
      @cli.prompt() if @options.terminal
      @emit 'finish' if @isClosed


module.exports = Shell
