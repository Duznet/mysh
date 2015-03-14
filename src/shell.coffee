_ = require 'underscore'
readline = require 'readline'
parse = require('shell-quote').parse
fs = require 'fs'
childProcess = require 'child_process'
EventEmitter = require('events').EventEmitter
streamify = require 'stream-array'
os = require 'os'

class Shell extends EventEmitter

  defaults:
    terminal: false
    prompt: 'mysh> '
    input: process.stdin
    output: process.stdout
    locals: {}
    env: process.env
    debug: false
    parseInfo: false


  initCli: (options) ->
    @cli = readline.createInterface options
    @cli.setPrompt options.prompt

    @cli.on 'line', @onLine
    @cli.on 'pause', @onPause
    @cli.on 'resume', @onResume
    @cli.on 'close', @onClose

  constructor: (options = {}) ->
    @options = {}
    @status = 'running'

    @queue = []
    @collectedQueue = []

    @stopLines = []
    @incLines = []
    @decLines = []
    @level = 0

    @forArrayData = []
    @forCounterName = 'i'

    @isPaused = false
    @isClosed = false

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
    if @options.lineInfo
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
    if @options.debug
      console.log 'closed!'
    @emit 'finish'

  done: (code) =>
    if @options.debug
      console.log 'done', code
    @cli.resume()

  commands:

    pwd: (done) ->
      console.log process.cwd()
      done 'pwd'

    cd: (done, dir) ->
      process.chdir dir
      done 'cd'

    ls: (done, path = process.cwd()) ->
      fs.readdir path, (err, files) ->
        result = ''
        for file in files
          result += file + '\t'
        console.log result
        done 'ls'

    run: (done, args...) ->
      childCmd = args[0]
      childArgs = _.rest args
      spawned = childProcess.spawn childCmd, childArgs, {env: @options.env, stdio: 'inherit'}
      spawned.on 'exit', (code) ->
        done 'run'
      spawned.on 'error', (err) ->
        console.log "could not run command: '#{childCmd}'"
        done 'run'

    source: (done, path) ->
      options =
        input: fs.createReadStream path
        output: process.stdout
      @spawnSubshell options, () =>
        done 'source'

    env: (done) ->
      for k, v of @options.env
        console.log "#{k}=#{v}"
      done 'env'

    locals: (done) ->
      for k, v of @options.locals
        console.log "#{k}=#{v}"
      done 'locals'

    set: (done, line) ->
      data = line.split '='
      varName = data[0]
      value = data[1]
      if @options.env[varName]?
        @options.env[varName] = value
      else
        @options.locals[varName] = value
      done 'set'

    export: (done, line) ->
      data = line.split '='
      if data.length is 2
        @options.env[data[0]] = data[1]
      else
        @options.env[data[0]] = @options.locals[data[0]]
      done 'export'

    echo: (done, args...) ->
      result = ''
      _.each args, (arg) ->
        if arg instanceof Object
          arg = arg.op
        result += arg + ' '
      console.log result
      done 'echo'


    if: (done, args...) ->
      expStr = ''
      for a in args
        expStr += if a instanceof Object then a.op else a
        expStr += ' '
      if @options.debug
        console.log "expression: '#{expStr}'"
      expRes = eval expStr
      if @options.debug
        console.log "expression result: '#{expRes}'"
      @incLines = ['if']
      @decLines = ['doneif']
      if expRes
        @status = 'collecting'
        @stopLines = ['doneif', 'else']
      else
        @status = 'skipping'
        @stopLines = ['else']
      done 'if'

    else: (done) ->
      @status = if @status is 'skipping' then 'collecting' else 'skipping'
      if @options.debug
        console.log 'status after else: ', @status
      @stopLines = ['doneif']
      done 'else'

    doneif: (done) ->
      @status = 'running'

      if @options.debug
        console.log 'collectedQueue:', @collectedQueue

      options =
        input: @makeShellStream @collectedQueue
        output: process.stdout

      @spawnSubshell options, () =>
        @collectedQueue = []
        done 'doneif'

    for: (done, args...) ->
      varName = args[0]
      # I believe args[1] is 'in'
      arrArgs = _.rest args, 2
      arrData = ''
      for a in arrArgs
        arrData += a + ' '
      if @options.debug
        console.log "arrData: #{arrData}"
      @status = 'collecting'
      @incLines = ['for']
      @decLines = ['donefor']
      @stopLines = ['donefor']

      @forCounterName = varName
      @forArrayData = eval arrData
      done 'for'

    donefor: (done) ->
      @status = 'running'
      if @options.debug
        console.log 'forArrayData:', @forArrayData

      @processForLoop done, 0


  processForLoop: (done, index) ->
    if index is @forArrayData.length
      @forArrayData = []
      done 'processForLoop'
      return

    counter = {}
    counter[@forCounterName] = @forArrayData[index]
    if @options.debug
      console.log 'counter:', counter
      console.log 'queue:', @collectedQueue
    options =
      input: @makeShellStream @collectedQueue
      output: process.stdout
      env: _.defaults counter, @options.env

    @spawnSubshell options, () =>
      @processForLoop(done, index + 1)

  makeShellStream: (data) ->
    newData = _.map data, (x) -> x + os.EOL
    return streamify newData

  spawnSubshell: (options, callback) ->
    options = _.defaults options, {terminal: false}, @options
    childShell = new Shell options
    childShell.on 'finish', callback

  process: (line) ->
    line = line.trim()

    parsed = parse line, _.extend(_.clone(@options.locals), @options.env)
    if @options.parseInfo
      console.log 'parsed:', parsed

    if parsed.length is 0
      @done 'process'
      return
    cmd = ''
    args = []
    if @commands[parsed[0]]?
      cmd = parsed[0]
      args = _.rest parsed
    else
      cmd = 'run'
      args = parsed

    if @options.debug
      console.log '---'
      console.log 'processing line:', line
      console.log 'level:', @level
      console.log 'status:', @status
      console.log 'incLines:', @incLines
      console.log 'decLines:', @decLines
      console.log 'stopLines:', @stopLines

    if (@status is 'skipping' or @status is 'collecting')
      if cmd not in @stopLines or @level > 0
        if cmd in @incLines
          ++@level
        if cmd in @decLines
          --@level
        if @status is 'collecting'
          @collectedQueue.push line
          if @options.debug
            console.log 'collectedQueue: ', @collectedQueue
        @done 'process'
        return

    if @options.debug
      console.log 'start', cmd
    @commands[cmd].apply this, [@done].concat(args)

  processQueue: () ->
    if @queue.length isnt 0
      line = @queue.shift()
      @cli.pause()
      @process line
    else
      if @options.terminal
        @cli.prompt()

module.exports = Shell
