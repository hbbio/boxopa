
import stdlib.themes.bootstrap.core
import stdlib.upload
import stdlib.io.file
import stdlib.web.client

type FileInfo = {
  name: string;
  id: string;
  mimetype: string;
}

type File = {
  name: string;
  id: string;
  mimetype: string;
  content: string
}

type Box = { files: list(File) }

db /box: stringmap(Box)
db /box[_] = { files = [] }

@server
hostname() = "http://localhost:8080"

@server
get_file_info(f: File) =
  { name = f.name;
    mimetype = f.mimetype; 
    id = f.id }

@server
box_url(id) = "{hostname()}/box/{id}"

@server
index_page() = 
(
  id = Random.string(8)
  Resource.page("Creating new box", 
// onclick="this.select();"
    <body>
      <a href="https://github.com/jvimal/boxopa" xmlns="http://www.w3.org/1999/xhtml">
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
                  <input type="text" id="perm" value="{box_url(id)}" />
                </div>
              </div>    
            </div>
          </div>
        </div>
      </div>
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
    </body>
  )
)

@server
create_file(bid, f) =
(
  do /box[bid]/files <- List.add(f, /box[bid]/files);
  void
)

@server
delete_file(bid, id) =
(
  files = /box[bid]/files
  room = network(bid)
  info = {id = id; name = ""; mimetype = ""}
  do /box[bid]/files <- List.remove_p((e -> e.id == id), files)
  Network.broadcast(info, room)
)

@server
get_image(m) =
  if String.has_prefix("image", m) then "/resources/img/boxopa-file-img.png"
  else "/resources/img/boxopa-file-misc.png"

@server
show_file(box, f) =
(
  <li class="span2" id="{f.id}">
    <div class="thumbnail">
      <div class="thumbnail-inner">
       <a href="/assets/{box}/{f.id}/{f.name}">
          <img src="{get_image(f.mimetype)}"/>
          <div class="download"></div>
       </a>
       <a href="#" class="circle" onclick={_ -> delete_file(box, f.id)} title="Remove">×</a>
      </div>
      <div class="caption">
        <h5><a href="/assets/{box}/{f.id}/{f.name}">{f.name}</></h5>
      </div>
    </div>
  </li>
)

@server
process_upload(bid,upload_data) =
(
  up_file = StringMap.get("upload", upload_data.uploaded_files)
  match up_file with
    | {some = f} -> 
          id = Random.string(8)
          name = f.filename
          mtype = f.mimetype
          content = f.content
          room = network(bid)
          info = { id = id;
                   name = name;
                   mimetype = mtype; }
          new_file = { id = id;
                       name = name;
                       mimetype = mtype;
                       content = content } // Storing file in database; work on C-extension
          do create_file(bid, new_file)
          do Network.broadcast(info, room)
          void
    | _ -> 
          do Dom.transform([#error +<- <h3>File uploading failed, please try again.</h3>])
          void
)

show_upload_form(bid) =
(
  Upload.html(
    { Upload.default_config() with
        form_id = "upload";
        form_body =
            <input type="file" name="upload" />
            <input type="submit" class="btn btn-success" value="Upload" />;
        process = a -> process_upload(bid, a);
     })
)


//add_file(bid) =
//(
//  Dom.transform([#up <- show_upload_form(bid)])
//)

network(id) : Network.network(FileInfo) =
  Network.cloud(id)

files_update(boxid, f: FileInfo) =
  if f.name != "" then
    Dom.transform([#files +<- show_file(boxid, f)])
  else
    Dom.remove(#{f.id})


@server
show_box(path) = 
(
  b = /box[path]
  room = network(path)
  callback = e -> files_update(path, e)
  finfo = List.map(get_file_info, b.files)
  Resource.styled_page("Showing box {path}", ["/css"],
//onclick="this.select();" />
    <body onready={_ -> Network.add_callback(callback, room)}>
      <a href="https://github.com/jvimal/boxopa" xmlns="http://www.w3.org/1999/xhtml">
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
                  <input type="text" id="perm" value="{box_url(path)}" />
              </div>
              </div>
            </div>
          </div>
        </div>
      </div>
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
    </body>
  )
)

do_404() = 
(
  Resource.styled_page("Oops", [],
    <h3>Sorry, we cannot find your page!</h3>
  )
)

deliver_assets(lst) =
  match lst with
    | [boxid, assetid, name] -> (
        files = /box[boxid]/files
        match List.find((e -> e.id == assetid && e.name == name), files) with
          | {some = file} -> Resource.raw_response(file.content, file.mimetype, {success})
          | _ -> Resource.raw_status({unauthorized})
      )
    | _ -> do_404()

@server
start(uri) = (
  match uri with
    | {path = {nil} ...} -> index_page()
    | {path = {hd="box" ~tl} ...} -> show_box(String.concat("", tl))
    | {path = {hd="assets" ~tl} ...} -> deliver_assets(tl)
    | {path = _ ...} -> do_404()
)

//server = Server.simple_dispatch(start)
_ = Server.start(Server.http,
        [{resources = @static_resource_directory("resources")},
         {register = ["/resources/css/bootstrap.min.css", "/resources/css/style.css", "/resources/js/bootstrap.min.js", "/resources/js/boxopa.js"]},
         {dispatch = start}] <: Server.handler)
    
