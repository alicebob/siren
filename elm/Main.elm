import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick, onDoubleClick)
import Html.Attributes as Attr
import Http
import WebSocket
import Json.Decode as Decode
import Json.Encode as Encode
import FontAwesome
import Color

import Mpd

icon_play = FontAwesome.play_circle
icon_pause = FontAwesome.pause_circle
icon_stop = FontAwesome.stop_circle
icon_previous = FontAwesome.chevron_circle_left
icon_next = FontAwesome.chevron_circle_right

main =
  Html.programWithFlags
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Model = 
    { wsURL : String
    , status : Mpd.Status
    , playlist : Mpd.Playlist
    , view : View
    , fileView : List Pane
    , artistView : List Pane
    }

init : { wsURL : String } -> (Model, Cmd Msg)
init flags =
  ( { wsURL = flags.wsURL
    , status = Mpd.newStatus
    , playlist = Mpd.newPlaylist
    , view = Playlist
    , fileView = [rootPane]
    , artistView = [artistPane]
    }
  , Cmd.batch
    [ wsSend flags.wsURL <| wsLoadDir rootPane.id
    , wsSend flags.wsURL <| wsList artistPane.id "artists" "" ""
    ]
  )

rootPane : Pane
rootPane =
    { id = ""
    , title = "/"
    , entries = []
    }

artistPane : Pane
artistPane =
    { id = "artists"
    , title = "Artist"
    , entries = []
    }

type View
  = Playlist
  | FileBrowser 
  | ArtistBrowser

type Msg
  = SendWS Encode.Value
  | IncomingWSMessage String
  | Show View
  | AddFilePane String Pane -- AddFilePane after newpane
  | AddArtistPane String Pane Encode.Value -- AddArtistPane after newpane

type alias PaneEntry =
    { id : String
    , title : String
    , current : Bool
    , onClick : Maybe Msg
    , onDoubleClick : Maybe Msg
    }

type alias Pane =
    { id : String
    , title : String
    , entries : List PaneEntry
    }


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    IncomingWSMessage m ->
      case Decode.decodeString Mpd.wsMsgDecoder m of
        Err e -> Debug.log ("json err: " ++ e) (model, Cmd.none)
        Ok s ->
            case s of
                Mpd.WSPlaylist p ->
                    ({ model | playlist = p }, Cmd.none)
                Mpd.WSStatus s -> 
                    ({ model | status = s }, Cmd.none)
                Mpd.WSInode s -> 
                    ({ model | fileView = setFilePane s model.fileView }, Cmd.none)
                Mpd.WSList s -> 
                    ({ model | artistView = setListPane s model.artistView }, Cmd.none)

    Show v ->
        -- TODO: update root if this is a file/artist viewer
        ({ model | view = v }, Cmd.none)

    AddFilePane after p ->
        ({ model | fileView = addPane model.fileView after p }
        , wsSend model.wsURL <| wsLoadDir p.id
        )

    AddArtistPane after p obj ->
        ({ model | artistView = addPane model.artistView after p }
        , wsSend model.wsURL obj
        )

    SendWS obj ->
        ( model
        , wsSend model.wsURL obj
        )


view : Model -> Html Msg
view model =
  div [Attr.class "mpd"]
    [ viewPlayer model
    , viewTabs model
    , viewView model
    , viewFooter
    ]

viewPlayer : Model -> Html Msg
viewPlayer model =
  let
    prettySong tr = tr.title ++ " by " ++ tr.artist
    song = prettySong <| Mpd.lookupPlaylist model.playlist model.status.songid
    prettySecs secsf =
        let secs = round secsf
            m = secs // 60
            s = secs % 60
        in toString m ++ ":" ++ (String.padLeft 2 '0' <| toString s)
    prettyTime = prettySecs model.status.elapsed ++ "/" ++ prettySecs model.status.duration
    state = model.status.state
    enbutton c i = Html.a [ Attr.class "enabled", onClick c ] [ i Color.black 42 ]
    disbutton i = Html.a [ ] [ i Color.darkGrey 42 ]
    buttons = case state of
        "play" ->
            [ disbutton icon_play
            , enbutton pressPause icon_pause
            , enbutton pressStop icon_stop
            ]
        "pause" ->
            [ enbutton pressPlay icon_play
            , enbutton pressUnPause icon_pause
            , enbutton pressStop icon_stop
            ]
        "stop" ->
            [ enbutton pressPlay icon_play
            , disbutton icon_pause
            , disbutton icon_stop
            ]
        _ -> []
  in
  div [Attr.class "player"] <|
    buttons
    ++
    [ enbutton pressPrevious icon_previous
    , enbutton pressNext icon_next
    , text " - "
    , text <| "Currently: " ++ state ++ " "
    ]
    ++ if state == "pause" || state == "play"
        then
            [ text <| "Song: " ++ song ++ " "
            , text <| "Time: " ++ prettyTime
            ]
        else []

viewTabs : Model -> Html Msg
viewTabs model =
  div [Attr.class "tabs"]
    [ button [ onClick <| Show Playlist ] [ text "playlist" ]
    , button [ onClick <| Show FileBrowser ] [ text "files" ]
    , button [ onClick <| Show ArtistBrowser ] [ text "artists" ]
    ]

viewView : Model -> Html Msg
viewView model =
  case model.view of
    Playlist -> viewViewPlaylist model
    FileBrowser -> viewViewFiles model
    ArtistBrowser -> viewViewArtists model
    
viewViewFiles : Model -> Html Msg
viewViewFiles model =
  div [Attr.class "nc"]
    <| List.map viewPane model.fileView

viewViewArtists : Model -> Html Msg
viewViewArtists model =
  div [Attr.class "nc"]
    <| List.map viewPane model.artistView

viewPane : Pane -> Html Msg
viewPane p =
  let
    viewLine e =
      div 
        (
          ( if e.current
              then [Attr.class "exp"]
              else [])
          ++ ( case e.onClick of
               Nothing -> []
               Just e -> [onClick e]
             )
          ++ ( case e.onDoubleClick of
               Nothing -> []
               Just e -> [onDoubleClick e]
             )
        )
        [ text e.title
        ]
  in
    div [] (
        Html.h1 [] [ text p.title ]   
        :: List.map viewLine p.entries
    )

viewViewPlaylist : Model -> Html Msg
viewViewPlaylist model =
  div [Attr.class "playlistwrap"]
    [ div [Attr.class "commands"]
      [ button [ onClick <| pressClear ] [ text "clear" ]
      ]
    , div [Attr.class "playlist"]
        ( List.map (\e -> div
                [ Attr.class (if model.status.songid == e.id then "current" else "")
                , onDoubleClick <| pressPlayID e.id
                ]
                [ text <| e.artist ++ " - " ++ e.title
                ]
            ) model.playlist
        )
    ]

viewFooter : Html Msg
viewFooter =
    Html.footer [] [ text "Footers are easy!" ]

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen model.wsURL IncomingWSMessage


addPane : List Pane -> String -> Pane -> List Pane
addPane panes after new =
    case panes of
        [] -> []
        p :: tail -> if p.id == after
            then p :: [ new ]
            else p :: addPane tail after new


wsSend : String -> Encode.Value -> Cmd msg
wsSend wsURL o = WebSocket.send wsURL <| Encode.encode 0 <| o


wsLoadDir : String -> Encode.Value
wsLoadDir id =
    Encode.object
        [ ("cmd", Encode.string "loaddir")
        , ("id", Encode.string id)
        ]

pressPlay = SendWS <| buildWsCmd "play"
pressStop = SendWS <| buildWsCmd "stop"
pressPause = SendWS <| buildWsCmd "pause"
pressUnPause = SendWS <| buildWsCmd "unpause"
pressClear = SendWS <| buildWsCmd "clear"
pressPlayID id = SendWS <| buildWsCmdID "playid" id
pressPrevious = SendWS <| buildWsCmd "previous"
pressNext = SendWS <| buildWsCmd "next"
playlistAdd id = SendWS <| buildWsCmdID "add" id

buildWsCmd : String -> Encode.Value
buildWsCmd cmd =
    Encode.object
        [ ("cmd", Encode.string cmd)
        ]

buildWsCmdID : String -> String -> Encode.Value
buildWsCmdID cmd id =
    Encode.object
        [ ("cmd", Encode.string cmd)
        , ("id", Encode.string id)
        ]

wsList : String -> String -> String -> String -> Encode.Value
wsList id what artist album =
    Encode.object
        [ ("cmd", Encode.string "list")
        , ("id", Encode.string id)
        , ("what", Encode.string what)
        , ("artist", Encode.string artist)
        , ("album", Encode.string album)
        ]

-- add to the current playlist
wsFindAdd : String -> String -> String -> Encode.Value
wsFindAdd artist album track =
    Encode.object
        [ ("cmd", Encode.string "findadd")
        , ("artist", Encode.string artist)
        , ("album", Encode.string album)
        , ("track", Encode.string track)
        ]

setFilePane : Mpd.Inodes -> List Pane -> List Pane
setFilePane inodes panes =
    case panes of
        [] -> []
        p :: tail -> if p.id == inodes.id
            then {p | entries = toFilePaneEntries inodes} :: tail
            else p :: setFilePane inodes tail

toFilePaneEntries : Mpd.Inodes -> List PaneEntry
toFilePaneEntries inodes =
  let entry e = case e of
          Mpd.Dir id d -> PaneEntry id d False
                    (Just (AddFilePane inodes.id (newPane id d)))
                    (Just <| playlistAdd id)
          Mpd.File id f -> PaneEntry id f False
                    Nothing
                    (Just <| playlistAdd id)
  in
    List.map entry inodes.inodes


setListPane : Mpd.DBList -> List Pane -> List Pane
setListPane db panes =
    case panes of
        [] -> []
        p :: tail -> if p.id == db.id
            then {p | entries = toListPaneEntries db} :: tail
            else p :: setListPane db tail

toListPaneEntries : Mpd.DBList -> List PaneEntry
toListPaneEntries ls =
  let
    entry e = case e of
        Mpd.DBArtist artist ->
            PaneEntry artist artist False
            (Just <| AddArtistPane
                        ls.id
                        (newPane ("artist" ++ artist) artist)
                        (wsList ("artist" ++ artist) "artistalbums" artist "")
            )
            (Just <| SendWS <| wsFindAdd artist "" "")
        Mpd.DBAlbum artist album ->
            PaneEntry album album False
            (Just <| AddArtistPane
                        ls.id
                        (newPane ("album" ++ artist ++ album) album)
                        (wsList ("album" ++ artist ++ album) "araltracks" artist album)
            )
            (Just <| SendWS <| wsFindAdd artist album "")
        Mpd.DBTrack artist album track ->
            PaneEntry track track False
            Nothing -- TODO: show song/file info pane
            (Just <| SendWS <| wsFindAdd artist album track)
  in
    List.map entry ls.list

newPane : String -> String -> Pane
newPane id title =
    { id=id, title=title, entries=[] } 
