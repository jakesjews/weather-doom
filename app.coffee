Promise   = require('bluebird')
Nightmare = require('nightmare')
fs        = Promise.promisifyAll(require('fs'))
request   = Promise.promisifyAll(require('request'))
mkdirp    = Promise.promisifyAll(require('mkdirp'))
rimraf    = Promise.promisify(require('rimraf'))
co        = Promise.coroutine

baseUrl = "https://web.archive.org"
linkList = []

run = co ->
  nightmare = new Nightmare(loadImages: false)
  linkList = yield nightmare
    .goto("https://web.archive.org/web/*/weather.com")
    .inject('js', 'scripts/jquery.min.js')
    .evaluate ->
      $('.pop li:first-child a').map(-> @href).toArray()

  yield nightmare.end()
  process.removeAllListeners('uncaughtException')

  imageList = []

  for link, i in linkList
    try
      nightmare = new Nightmare(loadImages: false)

      res = yield nightmare
        .goto(link)
        .evaluate ->
          heading: document.querySelector('.dl-content-wrap h1').innerText
          img: window
            .getComputedStyle(
              document.getElementById('wx-local-wrap'), false
            )
            .backgroundImage
            .slice(4, -1)

      imageList.push(res)
      yield nightmare.end()
      process.removeAllListeners('uncaughtException')
      console.log("read day #{i + 1} of #{linkList.length}")
    catch err
      console.error err

  yield rimraf('scraped')
  yield mkdirp.mkdirpAsync('scraped/images')

  html = """
  <!DOCTYPE html>
  <head>
    <style>
      .image {
        position:relative;
        float: left;
      }

      img {
        height: 400px;
      }

      .text {
        left: 0;
        position:absolute;
        text-align:center;
        top: 100px;
        width: 100%;
        color: #FF3300;
      }

      ul {
        list-style-type: none;
      }
    </style>
  </head>
  <body>
    <ul>
  """

  yield fs.appendFileAsync('scraped/index.html', html)

  for img, i in imageList
    imageFile = i + '.jpg'

    writeImage = new Promise (resolve, reject) ->
      request(img.img)
        .pipe(fs.createWriteStream("scraped/images/#{imageFile}"))
        .on('finish', resolve)

    row = """
      <li class="image">
        <img src='images/#{imageFile}'>
        <h1 class="text">#{img.heading}</h1>
      </li>
    """

    writeIndex = fs.appendFileAsync('scraped/index.html', row)
    yield writeImage
    yield writeIndex

    console.log("wrote day #{i + 1} of #{imageList.length}")

  htmlEnd = """
    </ul>
  </body>
  """

  yield fs.appendFileAsync('scraped/index.html', htmlEnd)
  process.exit()

run()
