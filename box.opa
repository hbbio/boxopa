
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
      <div class="navbar">
        <div class="navbar-inner">
          <div class="container">
            <a class="brand" href="#"><img src="resources/img/boxopa-logo.png" alt="boxopa"/></a>
            <div class="well pull-right">Share URL with friends: <input type="text" id="perm" value="{box_url(id)}" /></div>
          </div>
        </div>
      </div>
      <div id="content" class="container">
      <div class="span4 centered">
        <h1>Welcome. Your box has been created.</h1>
        <a class="box" href="/box/{id}">
           <div class="well">Click to open</div>
        </a>       
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
       <a href="/assets/{box}/{f.id}/{f.name}">
          <img src="{get_image(f.mimetype)}"/>
          <div class="download" style="display:none;"></div>
       </a>   
       <div class="caption">
          <h5><a href="/assets/{box}/{f.id}/{f.name}">{f.name}</></h5>
       </div>
    </div>
    <a href="#" class="cross" onclick={_ -> delete_file(box, f.id)} title="Remove">×</a>
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
          do Dom.remove(#upload)
          do Network.broadcast(info, room)
          void
    | _ -> 
          do Dom.remove(#upload)
          do Dom.transform([#error +<- <p>Error uploading file!</p>])
          void
)

show_upload_form(bid) =
(
  Upload.html(
    { Upload.default_config() with
        form_id = "upload";
        form_body =
            <input type="file" name="upload" />
            <input type="submit" class="btn" value="Upload!" />;
        process = a -> process_upload(bid, a);
     })
)


add_file(bid) =
(
  Dom.transform([#up <- show_upload_form(bid)])
)

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
      <div class="navbar">
        <div class="navbar-inner">
          <div class="container">
            <a class="brand" href="#"><img src="/resources/img/boxopa-logo.png" alt="boxopa"/></a>
            <div class="well pull-right">Share URL with friends: <input type="text" id="perm" value="{box_url(path)}" /></div>
          </div>
        </div>
      </div>
      <div id="content" class="container">
        <h1>This is your box.  Upload anything you want & share URL with friends.</h1>
        <h3>Click the file icon to download the file.</h3>
        <h3>Share URL with friends so they can download your files.</h3>
        <h3>All viewers of this page will see the files the instant they are uploaded.</h3>
        <ul class="thumbnails" id="files">
          {List.map(show_file(path,_), finfo)}
        </ul>
        <div id="up">
        </div>
        <div id="error">
        </div>
        <a class="btn btn-success" href="#" onclick={_ -> add_file(path)}>Add file</a>
      </div>
    </body>
  )
)

do_404() = 
(
  Resource.styled_page("Oops", [],
    <h1>Oops, we cannot find your page!</h1>
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
         {register = ["/resources/css/bootstrap.min.css", "/resources/css/style.css"]},
         {dispatch = start}] <: Server.handler)
    
