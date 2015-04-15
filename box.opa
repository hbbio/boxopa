import stdlib.{themes.bootstrap.core, upload, crypto, io.file, web.client}

type FileInfo = { string name, string id, string mimetype }

type File = { FileInfo info, binary content }

type Box = { list(File) files }

database stringmap(Box) /box
database /box[_] = { files: [] }

hostname = "http://localhost:8080"
repository = "hbbio/boxopa"

function box_url(id) {
  "{hostname}/box/{id}"
}

footer =
  <div class="footer centered">
    <span>Fork on <a target="_blank" href="https://github.com/{repository}">GitHub</a></span> ·
    <span>Built with <a target="_blank" href="http://opalang.org"><img src="/resources/img/opa-logo-small.png" alt="Opa"/></a></span>
  </div>

function header(id) {
  <a href="https://github.com/{repository}" target="_blank" xmlns="http://www.w3.org/1999/xhtml">
    <img style="position: absolute; top: 0; left: 0; border: 0;" src="https://a248.e.akamai.net/assets.github.com/img/ce742187c818c67d98af16f96ed21c00160c234a/687474703a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f6c6566745f677261795f3664366436642e706e67" alt="Fork me on GitHub"/>
  </a>
  <div class="navbar">
    <div class="navbar-inner">
      <div class="container">
        <div class="row">
          <div class="span4 offset4">
            <a class="brand" href="#"><img src="/resources/img/boxopa-logo.png" alt="boxopa"/></a>
            <div class="centered form-inline">
              <label>Your box URL </label>
              <input type="text" id="perm" value="{box_url(id)}" onclick={function(_) {Dom.trigger(#perm, {select})}} />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
}

function index_page() {
  id = Random.string(8)
  Resource.page("Creating new box",
    <body>
      {header(id)}
      <div id="content" class="container">
        <div class="row">
          <div class="span4 offset4 centered">
            <a class="box" href="/box/{id}">
              <div class="well">
                <h3>Click to open</h3>
              </div>
            </a>
            <h3>Welcome. Your box has been created.</h3>
          </div>
        </div>
      </div>
      {footer}
    </body>
  )
}

function create_file(bid, f) {
  /box[bid] <- { files <+ f }
}

function delete_file(bid, id) {
  files = /box[bid]/files
  room = network(bid)
  info = {~id, name: "", mimetype: ""}
  /box[bid]/files <- List.remove_p(function (e) {e.info.id == id}, files)
  Network.broadcast(info, room)
}

function get_image(m) {
  if (String.has_prefix("image", m))
    "/resources/img/boxopa-file-img.png"
  else
    "/resources/img/boxopa-file-misc.png"
}

server function show_file(box, f) {
  at = "/assets/{box}/{f.id}/{Crypto.Hash.md5(f.name)}"
  <li class="span2" id="{f.id}">
    <div class="thumbnail">
      <div class="thumbnail-inner">
      <a href="{at}">
        <img src="{get_image(f.mimetype)}"/>
        <div class="download"></div>
      </a>
      <a href="#" class="circle" onclick={function (_) { delete_file(box, f.id)}} title="Remove">×</a>
      </div>
      <div class="caption">
        <h5><a href="{at}">{f.name}</></h5>
      </div>
    </div>
  </li>
}

function process_upload(bid, upload_data) {
  up_file = StringMap.get("upload", upload_data.uploaded_files)
  match (up_file) {
  case {some: f}:
    room = network(bid)
    info = { id: Random.string(8),
             name: f.filename,
             mimetype: f.mimetype
           }
    new_file = { ~info, content: f.content }
     // Storing file in database; work on C-extension
    create_file(bid, new_file);
    Network.broadcast(info, room)
  default:
    #error =+ <h3>File uploading failed, please try again.</h3>
  }
}

function show_upload_form(bid) {
  Upload.html(
    { Upload.default_config() with
      form_id: "upload",
      form_body:
        <input type="file" name="upload" />
      <input type="submit" class="btn btn-success" value="Upload" />,
      process: process_upload(bid, _)
    }
  )
}

function Network.network(FileInfo) network(id) {
  Network.cloud(id)
}

function files_update(boxid, FileInfo f) {
  if (f.name != "")
    #files =+ show_file(boxid, f)
  else
    Dom.remove(#{f.id})
}

function show_box(path) {
  b = /box[path]
  room = network(path)
  callback = files_update(path, _)
  finfo = List.map(_.info, b.files)
  Resource.page("Showing box {path}",
    <body onready={function(_) { Network.add_callback(callback, room)}}>
      {header(path)}
      <div id="content" class="container">
        <div class="row">
          <div class="span4 offset4">
            <div id="up" class="well">
              {show_upload_form(path)}
            </div>
            <div id="error">
            </div>
          </div>
          <div class="span4">
              <h3>This is your box. Upload anything you want and share URL with your friends.
                <a href="#" class="btn btn-mini btn-info" rel="popover" data-content="<ul><li>To download the file click the file icon.</li><li>Share your box URL with friends so they can download your files.</li><li>All viewers of this page will see the files the instant they are uploaded.</li></ul>" data-original-title="Tips">View tips ›</a>
              </h3>
            </div>
        </div>
        <ul class="thumbnails" id="files">
          {List.map(show_file(path,_), finfo)}
        </ul>
      </div>
      {footer}
    </body>
  )
}

page_404 =
  Resource.styled_page("Oops", [],
    <h3>Sorry, we cannot find your page!</h3>
  )

function deliver_assets(lst) {
  match (lst) {
  case [boxid, assetid, name]:
    files = /box[boxid]/files
    function match_file(f) {
      f.info.id == assetid && Crypto.Hash.md5(f.info.name) == name
    }
    match (List.find(match_file, files)) {
    case {some: file}: Resource.raw_response(string_of_binary(file.content), file.info.mimetype, {success})
    default: Resource.raw_status({unauthorized})
    }
  default: page_404
  }
}

function start(Uri.relative uri) {
  match (uri) {
  case {path: [] ...}: index_page()
  case {path: ["box" | tl] ...}: show_box(String.concat("", tl))
  case {path: ["assets" | tl] ...}: deliver_assets(tl)
  default: page_404
  }
}

Server.start(Server.http,
  [ {resources: @static_resource_directory("resources")},
    {register:
      [ {doctype: {html5}},
        {css: ["/resources/css/bootstrap.min.css", "/resources/css/style.css"]},
        {js: ["/resources/js/bootstrap.min.js", "/resources/js/boxopa.js"]}
      ]},
    {dispatch: start}
  ]
)
