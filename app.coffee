Nightmare = require('nightmare')
fs        = require('fs')
request   = require('request')
mkdirp    = require('mkdirp')
rimraf    = require('rimraf')

baseUrl = "https://web.archive.org"
linkList = []

await new Nightmare(loadImages: false)
  .goto("https://web.archive.org/web/*/weather.com")
  .evaluate ->
    $('.pop li:first-child a').map(-> @href).toArray()
  , (res) ->
    linkList = res
  .run defer()

imageList = []

for link, i in linkList
  await new Nightmare(loadImages: false)
    .goto(link)
    .wait('.dl-content-wrap h1')
    .wait('#wx-local-wrap')
    .evaluate ->
      heading: document.querySelector('.dl-content-wrap h1').innerText
      img: window
        .getComputedStyle(
          document.getElementById('wx-local-wrap'), false
        )
        .backgroundImage
        .slice(4, -1)
    , (res) ->
      imageList.push(res)
    .run defer()

await rimraf('scraped', defer())
await mkdirp('scraped/images', defer())

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

await fs.appendFile('scraped/index.html', html, defer())

for img, i in imageList
  imageFile = i + '.jpg'

  await
    request(img.img)
      .pipe(fs.createWriteStream("scraped/images/#{imageFile}"))
      .on('finish', defer())

    row = """
      <li class="image">
        <img src='images/#{imageFile}'>
        <h1 class="text">#{img.heading}</h1>
      </li>
    """

    fs.appendFile('scraped/index.html', row, defer())

htmlEnd = """
  </ul>
</body>
"""

await fs.appendFile('scraped/index.html', htmlEnd, defer())
