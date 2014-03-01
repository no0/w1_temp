fs = require 'fs'
http = require 'http'
path = require 'path'

express = require 'express'

coffeescript = require 'connect-coffee-script'
async = require 'async'
sqlite3 = require 'sqlite3'

base_dir = '/sys/bus/w1/devices'
readingOk = /YES$/
sensors = 
  '/sys/bus/w1/devices/28-000004b2ae2d/w1_slave': 'u'
  # '/sys/bus/w1/devices/28-000004b2ef65/w1_slave': 'o'
  '/sys/bus/w1/devices/28-000004b3782b/w1_slave': 'g'
lastReading = []

writeTemps = (temps) ->
  for t in temps
    db.run 'INSERT into temp_readings (timestamp, reading, loc) VALUES (datetime(\'now\', \'localtime\'), ?, ?)', t.reading, t.loc

readFiles = (files, cb) ->
  readFile = (file, cb) ->
    fs.readFile file, {encoding: 'utf-8'}, (err, data) ->
      throw err if err
      lines = data.split '\n'
      if readingOk.test lines[0]
        tempStr = lines[1].split('t=')[1]
        temp = loc: sensors[file], reading: parseInt(tempStr, 10) / 1000 * (9/5) + 32
      cb null, temp
  async.mapSeries files, readFile, (err, temps) ->
    cb null, temps

emitNewTemps = (temps) ->
  console.log lastReading = temps
  io.sockets.emit 'temp', temps

readAndRecord = (cb) ->
  async.waterfall [
    (cb) -> readFiles Object.keys(sensors), cb
    (temps, cb) ->
      emitNewTemps temps
      writeTemps temps
      cb()
    ], ->
      cb()

rwLoop = ->
  readAndRecord ->
    setTimeout rwLoop, 60 * 1000

db = new sqlite3.Database 'db/temps.db', -> rwLoop()

app = express()

app.set 'env', process.env.ENV or 'dev'
app.set 'port', process.env.PORT or 3000
app.use express.logger 'dev'
app.use express.urlencoded()
app.use express.methodOverride()
app.use express.bodyParser()
app.use app.router
app.use coffeescript src: path.join __dirname, 'public'
app.use express.static path.join __dirname, 'public'
if 'development' is app.get('env')
  app.use express.errorHandler()

app.get '/temps', (req, res) ->
  timeAgo = parseInt(req.query.ago, 10) or 5
  sql = "select * from temp_readings where timestamp > datetime('now', '-#{timeAgo} minutes', 'localtime')"
  db.all sql, (err, rows) -> res.json rows
app.get '/last', (req, res) -> res.json lastReading

server = http.createServer(app).listen app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'))
io = require('socket.io').listen server

module.export = app

