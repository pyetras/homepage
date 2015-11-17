gulp = require 'gulp'
es = require 'event-stream'
plugins = require('gulp-load-plugins')()
path = require('path')
lazypipe = require 'lazypipe'
_ = require 'lodash'
runSequence = require('run-sequence')
del = require('del')
mainBowerFiles = require('main-bower-files')
vinylPaths = require('vinyl-paths')

gulp.task 'build', ['less', 'coffee', 'js', 'slim', 'images', 'fonts', 'inject', 'misc']

gulp.task 'default', ['connect', 'build'], ->
  gulp.start('watch')

gulp.task 'deploy', ->
  gulp.src('./build/**/*').pipe plugins.ghPages(branch: 'master')

sources =
  less: ['./assets/styles/**/*.less', '!./assets/styles/**/_*.less']
  coffee: './assets/js/**/*.coffee'
  js: './assets/js/**/*.js'
  images: './assets/images/**/*'
  slim: ['./views/**/*.slim', '!./views/**/_*.slim']
  misc: './assets/misc/*'
  fonts: './assets/fonts/*'


gulp.task 'connect', ->
  plugins.connect.server({
    root: ['build'],
    port: 1337
  })

watcher = ->
  plugins.livereload.listen()

  gulp.src(sources.less[0])
    .pipe(plugins.watch sources.less[0], plugins.batch (events, done) ->
      gulp.start('inject:css', done)
    )

  removedFilter = () ->
    plugins.filter((file) ->
      file.event != 'deleted' && file.event != undefined
    )

  gulp.src sources.coffee
    .pipe(plugins.watch sources.coffee)
    .pipe(removedFilter())
    .pipe(coffeePipe())
    .pipe(plugins.livereload())
    .pipe(gulp.start 'inject:bower')

  gulp.src sources.js
    .pipe(plugins.watch sources.js)
    .pipe(removedFilter())
    .pipe(jsPipe())
    .pipe(plugins.livereload())
    .pipe(gulp.start 'inject:bower')

  gulp.src(sources.images)
    .pipe(plugins.watch sources.images)
    .pipe(removedFilter())
    .pipe(imagesPipe())
    .pipe(plugins.livereload())
    .pipe(plugins.notify {message : 'Images updated' })

  gulp.watch ['./views/**/*.slim'], ['slim', 'inject:bower']

  gulp.watch 'bower.json', ['inject:bower']

gulp.task 'watch', -> watcher()

lessPipe = lazypipe()
  .pipe(plugins.sourcemaps.init)
  .pipe(plugins.less, {paths: [path.join(__dirname, 'bower_components')]})
  .pipe(plugins.autoprefixer)
  .pipe(plugins.sourcemaps.write)
  .pipe(plugins.concatCss, 'style.css')
  .pipe(gulp.dest, './build/assets/styles')
  .pipe(plugins.livereload)
  .pipe(plugins.notify, {onLast: true, message : 'Less compiled' })

gulp.task 'less', ->
  gulp.src(sources.less)
    .pipe(lessPipe())

coffeePipe = lazypipe()
  .pipe(plugins.rename, (path) ->
    path.basename = path.basename.replace(/\.js$/i, '')
    return
  )
  .pipe(plugins.newer, {dest: './build/assets/js', ext: '.js'})
  .pipe(plugins.sourcemaps.init)
  .pipe(plugins.coffee, bare: true, sourceMap: true)
  .pipe(plugins.sourcemaps.write)
  .pipe(gulp.dest, './build/assets/js')
  .pipe(plugins.notify, {onLast: true, message : 'Coffee compiled' })

gulp.task 'coffee', ->
  gulp.src(sources.coffee)
    .pipe(coffeePipe())

jsPipe = lazypipe()
  .pipe(gulp.dest, './build/assets/js')

gulp.task 'js', ->
  gulp.src(sources.js)
    .pipe(plugins.newer('./build/assets/js'))
    .pipe(jsPipe())

slimPipe = lazypipe()
  .pipe(plugins.slim, pretty: true)
  .pipe(gulp.dest, './build')

# gulp.task 'html', ->
#   gulp.src(sources.templates)
#     .pipe(htmlTplPipe())

gulp.task 'slim', ->
  views = gulp.src(sources.slim)
    .pipe(slimPipe())
    .pipe(plugins.notify({onLast: true, message : 'Slim compiled' }))

injection = ->
  cssSrc = ['./build/assets/styles/**/*.css']
  styles = gulp.src(cssSrc, read: false)
  js = gulp.src('./build/assets/js/**/*.js', read: false)
  bower = gulp.src(mainBowerFiles())
    .pipe(gulp.dest('./build/assets/vendor'))

  transformer = (p) ->
    p = path.relative('./build', p)
    switch path.extname(p)
      when '.js'
        "<script src=\"./#{p}\"></script>"
      when '.css'
        "<link rel=\"stylesheet\" href=\"./#{p}\">"

  gulp.src('./build/layout.html')
    .pipe(vinylPaths(del))
    .pipe(plugins.inject(bower, {
      starttag: '<!--inject:vendor:{{ext}}-->'
      endtag: '<!--endinject-->'
      addRootSlash: false
      transform: transformer
    }))

    .pipe(plugins.inject(es.merge(styles, js), {
      starttag: '<!--inject:{{ext}}-->'
      endtag: '<!--endinject-->'
      addRootSlash: false
      transform: transformer
    }))

    .pipe(plugins.rename('index.html'))
    .pipe(gulp.dest('./build'))

gulp.task 'inject', ['slim', 'coffee', 'js', 'less'], injection

gulp.task 'inject:js', ['slim', 'coffee', 'js'], injection
gulp.task 'inject:css', ['slim', 'less'], injection
gulp.task 'inject:bower', ['slim'], injection

imagesPipe = lazypipe()
  .pipe(gulp.dest, './build/images')

gulp.task 'images', ->
  gulp.src(sources.images)
    .pipe(plugins.newer './build/images')
    .pipe(imagesPipe())

gulp.task 'fonts', ->
  gulp.src(sources.fonts)
    .pipe(gulp.dest('./build/assets/fonts'))

gulp.task 'misc', ->
  gulp.src(sources.misc)
    .pipe(gulp.dest('./build'))

gulp.task 'clean', ->
  del [
    'build/**'
  ]
