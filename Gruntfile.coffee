module.exports = (grunt) ->

  grunt.initConfig

    coffee:
      scripts:
          expand: true
          cwd: 'src/'
          src: ['*.coffee']
          dest: 'build/'
          ext: '.js'

    watch:
      scripts:
        files: ['src/*.coffee']
        tasks: ['newer:coffee']

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-newer'

  grunt.registerTask 'default', ['coffee', 'watch']
