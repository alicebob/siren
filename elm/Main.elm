import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Html.Attributes as Attr
import Http
import WebSocket
import Json.Decode as Decode


main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Model = 
    { status : Status
    , playlist : Playlist
    , view : View
    }

init : (Model, Cmd Msg)
init =
  ( Model newStatus newPlaylist Playlist
  , Cmd.none
  )


type View
  = Playlist
  | FileBrowser 
  | ArtistBrowser

type Msg
  = PressPlay
  | PressPause
  | PressStop
  | PressRes (Result Http.Error String)
  | NewWSMessage String
  | Show View


type alias Status =
    { state : String -- "play", ...
    , songid : String
    , time : String
    , elapsed : String
    }

newStatus : Status
newStatus = {state="", songid="", time="", elapsed=""}

type alias Track =
    { id : String
    , file : String
    , artist : String
    , album : String
    , title : String
    }

type alias Playlist = List Track

newPlaylist : Playlist
newPlaylist = []

type WSMsg
    = WSStatus Status
    | WSPlaylist Playlist


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    PressPlay ->
      (model, doAction "play")

    PressPause ->
      (model, doAction "pause")

    PressStop ->
      (model, doAction "stop")

    PressRes (Ok newUrl) ->
      (model , Cmd.none)

    PressRes (Err _) ->
      (model, Cmd.none) -- TODO: log or something

    NewWSMessage m ->
      case Decode.decodeString wsMsgDecoder m of
        Err e -> Debug.log ("json err: " ++ e) (model, Cmd.none)
        Ok s ->
            case s of
                WSPlaylist p ->
                    ({ model | playlist = p }, Cmd.none)
                WSStatus s -> 
                    ({ model | status = s }, Cmd.none)

    Show v ->
        ({ model | view = v }, Cmd.none)

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
    [ div []
        [ Html.h1 [] [ text "/" ]   
        , div [] [ text "line 1" ]
        , div [Attr.class "exp"] [ text "line 2" ]
        , div [] [ text "line 3" ]
        , div [] [ text "line 4" ]
        , div [] [ text "line 5" ]
        ]
    ]

viewViewPlaylist : Model -> Html Msg
viewViewPlaylist model =
  div [Attr.class "playlist"]
    [ div []
        ( List.map (\e -> div
                [ Attr.class (if model.status.songid == e.id then "current" else "")
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
  WebSocket.listen "ws://localhost:6601/mpd/ws" NewWSMessage


doAction : String -> Cmd Msg
doAction a =
  let
    url =
      "/mpd/" ++ a
  in
    Http.send PressRes (Http.getString url)

wsMsgDecoder : Decode.Decoder WSMsg
wsMsgDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen (\t ->
            case t of
                "status" -> Decode.field "msg" (Decode.map WSStatus statusDecoder)
                "playlist" -> Decode.field "msg" (Decode.map WSPlaylist playlistDecoder)
                _  -> Debug.crash("unknown type field")
        )

statusDecoder : Decode.Decoder Status
statusDecoder =
    Decode.map4
      Status
      (Decode.field "state" Decode.string)
      (Decode.field "songid" Decode.string)
      (Decode.field "time" Decode.string)
      (Decode.field "elapsed" Decode.string)

trackDecoder : Decode.Decoder Track
trackDecoder =
    Decode.map5
      Track
      (Decode.field "id" Decode.string)
      (Decode.field "file" Decode.string)
      (Decode.field "artist" Decode.string)
      (Decode.field "album" Decode.string)
      (Decode.field "title" Decode.string)

playlistDecoder : Decode.Decoder Playlist
playlistDecoder = Decode.list trackDecoder
