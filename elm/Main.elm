import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick, onDoubleClick)
import Html.Attributes as Attr
import Http
import WebSocket
import Json.Decode as Decode
import Json.Encode as Encode

import Mpd


main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Model = 
    { status : Mpd.Status
    , playlist : Mpd.Playlist
    , view : View
    , fileView : ViewFilebrowser
    }

init : (Model, Cmd Msg)
init =
  ( Model Mpd.newStatus Mpd.newPlaylist Playlist [rootPane]
  , wsLoadDir rootPane.id
  )

rootPane : Pane
rootPane =
    { id = ""
    , title = "/"
    , entries = []
    }


type View
  = Playlist
  | FileBrowser 
  | ArtistBrowser

type Msg
  = PressPlay
  | PressPause
  | PressStop
  | PressPlayID String
  | PressRes (Result Http.Error String)
  | NewWSMessage String
  | Show View
  | AddPane String Pane -- AddPane after newpane

type alias PaneEntry =
    { id : String
    , title : String
    , current : Bool
    , onClick : Maybe Msg
    }
type alias Pane =
    { id : String
    , title : String
    , entries : List PaneEntry
    }

type alias ViewFilebrowser = List Pane

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    PressPlay ->
      (model, doAction "play")

    PressPause ->
      (model, doAction "pause")

    PressStop ->
      (model, doAction "stop")

    PressPlayID e ->
      (model, doAction <| "track/" ++ e ++ "/play")

    PressRes (Ok newUrl) ->
      (model , Cmd.none)

    PressRes (Err _) ->
      (model, Cmd.none) -- TODO: log or something

    NewWSMessage m ->
      case Decode.decodeString Mpd.wsMsgDecoder m of
        Err e -> Debug.log ("json err: " ++ e) (model, Cmd.none)
        Ok s ->
            case s of
                Mpd.WSPlaylist p ->
                    ({ model | playlist = p }, Cmd.none)
                Mpd.WSStatus s -> 
                    ({ model | status = s }, Cmd.none)
                Mpd.WSInode s -> 
                    ({ model | fileView = setPane s model.fileView }, Cmd.none)

    Show v ->
        ({ model | view = v }, Cmd.none)

    AddPane after p ->
        ({ model | fileView = addPane model.fileView after p }
        , wsLoadDir p.id
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
  div [Attr.class "player"]
    [ button [ onClick PressPlay ] [ text "⏯" ]
    , button [ onClick PressPause ] [ text "⏸" ]
    , button [ onClick PressStop ] [ text "⏹" ]
    , text " - "
    , text <| "Currently: " ++ model.status.state ++ " "
    , text <| "Song: " ++ model.status.songid ++ " "
    , text <| "Time: " ++ model.status.elapsed ++ "/" ++ model.status.time
    ]

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
    ArtistBrowser -> viewViewFiles model
    
viewViewFiles : Model -> Html Msg
viewViewFiles model =
  div [Attr.class "nc"]
    <| List.map viewPane model.fileView

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
  div [Attr.class "playlist"]
    [ div []
        ( List.map (\e -> div
                [ Attr.class (if model.status.songid == e.id then "current" else "")
                , onDoubleClick <| PressPlayID e.id
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
  WebSocket.listen wsURL NewWSMessage

wsURL : String
wsURL = "ws://localhost:6601/mpd/ws"


doAction : String -> Cmd Msg
doAction a =
  let
    url = "/mpd/" ++ a
  in
    Http.send PressRes (Http.getString url)


addPane : List Pane -> String -> Pane -> List Pane
addPane panes after new =
    case panes of
        [] -> []
        p :: tail -> if p.id == after
            then p :: [ new ]
            else p :: addPane tail after new

wsLoadDir : String -> Cmd msg
wsLoadDir id =
    WebSocket.send wsURL <| Encode.encode 0 <| Encode.object
        [ ("cmd", Encode.string "loaddir")
        , ("id", Encode.string id)
        ]

setPane : Mpd.Inodes -> List Pane -> List Pane
setPane inodes panes =
    case panes of
        [] -> []
        p :: tail -> if p.id == inodes.id
            then {p | entries = toPaneEntries inodes} :: tail
            else p :: setPane inodes tail

toPaneEntries : Mpd.Inodes -> List PaneEntry
toPaneEntries inodes =
  let entry e =
      case e of
          Mpd.Dir id d -> PaneEntry id d False (Just (AddPane inodes.id (newPane id d)))
          Mpd.File id f -> PaneEntry id f False Nothing
  in
    List.map entry inodes.inodes

newPane : String -> String -> Pane
newPane id title =
    { id=id, title=title, entries=[] } 
