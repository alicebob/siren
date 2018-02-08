module Main exposing (..)

import Color
import Dom.Scroll as Scroll
import Explicit as Explicit
import FontAwesome
import Html exposing (Html, button, div, text)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Mpd
import Pane
import Platform
import Process
import Task
import Time


type alias MPane =
    Pane.Pane Msg


icon_play =
    FontAwesome.play_circle


icon_pause =
    FontAwesome.pause_circle


icon_stop =
    FontAwesome.stop_circle


icon_previous =
    FontAwesome.chevron_circle_left


icon_next =
    FontAwesome.chevron_circle_right


icon_replace =
    FontAwesome.play_circle


icon_add =
    FontAwesome.plus_circle


doubleClick =
    replaceAndPlay


main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type Dragging
    = Dragging SliderType DragState Float
    | NotDragging


type SliderType
    = SliderSeek
    | SliderVolume


type DragState
    = Drag
    | Wait


type alias Model =
    { wsURL : String
    , status : Maybe Mpd.Status
    , statusT : Time.Time
    , playlist : Mpd.Playlist
    , view : View
    , fileView : List MPane
    , artistView : List MPane
    , now : Time.Time
    , dragging : Dragging
    , conn : Maybe Explicit.WebSocket
    , mpdOnline : Bool
    }


init : { wsURL : String } -> ( Model, Cmd Msg )
init flags =
    ( { wsURL = flags.wsURL
      , status = Nothing
      , statusT = 0
      , playlist = Mpd.newPlaylist
      , view = Playlist
      , fileView = [ rootPane ]
      , artistView = [ artistPane ]
      , now = 0
      , dragging = NotDragging
      , conn = Nothing
      , mpdOnline = False
      }
    , Cmd.batch
        [ Task.perform Tick Time.now
        , connect flags.wsURL
        ]
    )


connect : String -> Cmd Msg
connect url =
    Explicit.open url
        { onOpen = WSOpen
        , onMessage = WSMessage
        , onClose = WSDisconnect
        }


rootPane : MPane
rootPane =
    Pane.newPane "root" "/" <| cmdLoadDir "root" ""


artistPane : MPane
artistPane =
    Pane.newPane "artists" "Artist" <| cmdList "artists" "artists" "" ""


type View
    = Playlist
    | FileBrowser
    | ArtistBrowser


type Msg
    = SendWS String -- encoded json
    | Show View
    | AddFilePane String MPane -- AddFilePane after newpane
    | AddArtistPane String MPane -- AddArtistPane after newpane
    | Tick Time.Time
    | Seek String Float
    | StartDrag SliderType Float
    | SetVolume Float
    | Connect
    | WSOpen (Result String Explicit.WebSocket)
    | WSMessage String
    | WSDisconnect String
    | Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        WSMessage m ->
            case Decode.decodeString Mpd.wsMsgDecoder m of
                Err e ->
                    Debug.log ("json err: " ++ e) ( model, Cmd.none )

                Ok s ->
                    case s of
                        Mpd.WSConnection mpd ->
                            ( { model | mpdOnline = mpd }, Cmd.none )

                        Mpd.WSPlaylist p ->
                            ( { model | playlist = p }, Cmd.none )

                        Mpd.WSStatus s ->
                            ( { model
                                | status = Just s
                                , dragging =
                                    case model.dragging of
                                        Dragging _ Wait _ ->
                                            NotDragging

                                        _ ->
                                            model.dragging
                                , statusT = model.now
                              }
                            , Cmd.none
                            )

                        Mpd.WSInode id s ->
                            ( { model | fileView = setFilePane id s model.fileView }, Cmd.none )

                        Mpd.WSList id s ->
                            ( { model | artistView = setListPane id s model.artistView }, Cmd.none )

                        Mpd.WSTrack id t ->
                            ( { model
                                | fileView = setTrackPane id t model.fileView
                                , artistView = setTrackPane id t model.artistView
                              }
                            , Cmd.none
                            )

                        Mpd.WSDatabase ->
                            ( model
                            , Cmd.batch
                                [ reloadFiles model
                                , reloadArtists model
                                ]
                            )

        Show Playlist ->
            ( { model | view = Playlist }, Cmd.none )

        Show FileBrowser ->
            ( { model | view = FileBrowser }
            , reloadFiles model
            )

        Show ArtistBrowser ->
            ( { model | view = ArtistBrowser }
            , reloadArtists model
            )

        AddFilePane after p ->
            ( { model | fileView = Pane.addPane model.fileView after p }
            , Cmd.batch
                [ scrollNC
                , wsSend model.conn p.update
                ]
            )

        AddArtistPane after p ->
            ( { model | artistView = Pane.addPane model.artistView after p }
            , Cmd.batch
                [ scrollNC
                , wsSend model.conn p.update
                ]
            )

        SendWS payload ->
            ( model
            , wsSend model.conn payload
            )

        Tick t ->
            ( { model | now = t }
            , Cmd.none
            )

        Seek id s ->
            case model.dragging of
                Dragging SliderSeek Drag _ ->
                    ( { model | dragging = Dragging SliderSeek Wait s }
                    , wsSend model.conn <| cmdSeek id s
                    )

                Dragging SliderSeek _ _ ->
                    ( { model | dragging = NotDragging }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SetVolume v ->
            case model.dragging of
                Dragging SliderVolume Drag _ ->
                    ( { model | dragging = Dragging SliderVolume Wait v }
                    , wsSend model.conn <| cmdSetVolume v
                    )

                Dragging SliderVolume _ _ ->
                    ( { model | dragging = NotDragging }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        StartDrag slider value ->
            ( { model | dragging = Dragging slider Drag value }, Cmd.none )

        Connect ->
            ( model, connect model.wsURL )

        WSOpen (Ok ws) ->
            ( { model | conn = Just ws }, Cmd.none )

        WSOpen (Err err) ->
            ( { model
                | conn = Debug.log ("ws conn error: " ++ err) Nothing
                , mpdOnline = False
              }
            , Task.perform (always Connect) <| Process.sleep (5 * Time.second)
            )

        WSDisconnect reason ->
            ( { model
                | conn = Debug.log ("ws disconnected, reason: " ++ reason) Nothing
                , mpdOnline = False
              }
            , Cmd.none
            )

        Noop ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ Attr.class "mpd" ]
        [ viewHeader model
        , viewView model
        ]


viewPlayer : Model -> Html Msg
viewPlayer model =
    div [ Attr.class "player" ] <|
        case model.status of
            Nothing ->
                [ text "Loading..." ]

            Just status ->
                let
                    song =
                        Mpd.lookupPlaylist model.playlist status.songid

                    realElapsed =
                        status.elapsed
                            + (case status.state of
                                "play" ->
                                    Time.inSeconds <| model.now - model.statusT

                                _ ->
                                    0
                              )

                    prettyTime =
                        prettySecs realElapsed ++ "/" ++ prettySecs status.duration

                    enbutton c i =
                        Html.a [ Attr.class "enabled", Events.onClick c ] [ i Color.black 42 ]

                    disbutton i =
                        Html.a [] [ i Color.darkGrey 42 ]

                    buttons =
                        div
                            [ Attr.class "buttons" ]
                        <|
                            case status.state of
                                "play" ->
                                    [ enbutton pressPrevious icon_previous
                                    , enbutton pressPause icon_pause
                                    , enbutton pressStop icon_stop
                                    , enbutton pressNext icon_next
                                    ]

                                "pause" ->
                                    [ enbutton pressPrevious icon_previous
                                    , enbutton pressPlay icon_play
                                    , enbutton pressStop icon_stop
                                    , enbutton pressNext icon_next
                                    ]

                                "stop" ->
                                    [ enbutton pressPrevious icon_previous
                                    , enbutton pressPlay icon_play
                                    , disbutton icon_stop
                                    , enbutton pressNext icon_next
                                    ]

                                _ ->
                                    []

                    targetValueAsNumber : Decode.Decoder Float
                    targetValueAsNumber =
                        Decode.at [ "target", "valueAsNumber" ] Decode.float

                    seek =
                        let
                            v =
                                case model.dragging of
                                    Dragging SliderSeek _ v ->
                                        v

                                    _ ->
                                        realElapsed
                        in
                        Html.input
                            [ Attr.type_ "range"
                            , Attr.min "0"
                            , Attr.max (toString status.duration)
                            , Events.on "input" (Decode.map (StartDrag SliderSeek) targetValueAsNumber)
                            , Events.on "change" (Decode.map (Seek status.songid) targetValueAsNumber)
                            , Attr.value (toString v)
                            ]
                            []

                    volume =
                        let
                            v =
                                case model.dragging of
                                    Dragging SliderVolume _ v ->
                                        v

                                    _ ->
                                        status.volume
                        in
                        div []
                            [ FontAwesome.volume_down Color.black 12
                            , Html.input
                                [ Attr.type_ "range"
                                , Attr.min "0"
                                , Attr.max "100"
                                , Events.on "input" (Decode.map (StartDrag SliderVolume) targetValueAsNumber)
                                , Events.on "change" (Decode.map SetVolume targetValueAsNumber)
                                , Attr.value (toString v)
                                ]
                                []
                            , FontAwesome.volume_up Color.black 12
                            ]
                in
                [ buttons
                ]
                    ++ (if status.state == "pause" || status.state == "play" then
                            [ div [ Attr.class "title" ] [ text song.title ]
                            , div [ Attr.class "artist" ] [ text song.artist ]
                            , div [ Attr.class "time" ]
                                [ seek
                                , Html.div [] [ text prettyTime ]
                                ]
                            ]

                        else
                            []
                       )
                    ++ [ volume
                       ]


viewHeader : Model -> Html Msg
viewHeader model =
    let
        count =
            " (" ++ (toString <| List.length model.playlist) ++ ")"

        tab what t =
            Html.a
                [ Events.onClick <| Show what
                , Attr.class <|
                    "tab "
                        ++ (if model.view == what then
                                "curr"

                            else
                                ""
                           )
                ]
                [ text t ]

        ( titleClick, titleTitle, titleHover ) =
            case ( model.conn, model.mpdOnline ) of
                ( Nothing, _ ) ->
                    ( Connect, "[Siren (offline)]", "offline. Click to reconnect" )

                ( Just _, False ) ->
                    ( Show Playlist, "[Siren] (online, but no mpd)", "connected to the Siren daemon, but no connection to the MPD" )

                ( Just _, True ) ->
                    ( Show Playlist, "[Siren] (online)", "connected to the Siren daemon, and to the MPD" )
    in
    div [ Attr.class "header" ]
        [ Html.a
            [ Attr.class "title"
            , Events.onClick titleClick
            , Attr.title titleHover
            ]
            [ text titleTitle ]
        , tab Playlist <| "Playlist" ++ count
        , tab FileBrowser "Files"
        , tab ArtistBrowser "Artists"
        ]


viewView : Model -> Html Msg
viewView model =
    case model.view of
        Playlist ->
            viewPlaylist model

        FileBrowser ->
            Lazy.lazy viewPanes model.fileView

        ArtistBrowser ->
            Lazy.lazy viewPanes model.artistView


viewPanes : List MPane -> Html Msg
viewPanes ps =
    div [ Attr.class "nc", Attr.id "nc" ] <|
        List.concat <|
            List.map viewPane ps


viewPane : MPane -> List (Html Msg)
viewPane p =
    let
        viewEntry : Pane.Entry Msg -> Html Msg
        viewEntry e =
            div
                (List.filterMap identity
                    [ if p.current == Just e.id then
                        Just <| Attr.class "exp"

                      else
                        Nothing
                    , Maybe.map Events.onClick e.onClick
                    , case e.selection of
                        Nothing ->
                            Nothing

                        Just p ->
                            Just <| Events.onDoubleClick <| doubleClick p
                    ]
                )
                [ div [] [ text e.title ]
                , div [ Attr.class "arrow" ] [ text "▸" ]
                ]

        viewBody : Pane.Body Msg -> List (Html Msg)
        viewBody b =
            case b of
                Pane.Plain a ->
                    List.singleton a

                Pane.Entries es ->
                    List.map viewEntry es

        playlists : List String
        playlists =
            case p.body of
                Pane.Plain a ->
                    []

                Pane.Entries es ->
                    List.filterMap .selection <|
                        List.filter (\e -> p.current == Just e.id) es
    in
    [ div [ Attr.class "title", Attr.title p.title ]
        [ text p.title ]
    , div [ Attr.class "pane" ] <|
        viewBody p.body
    , div [ Attr.class "footer" ] <|
        case playlists of
            [] ->
                []

            h :: _ ->
                [ Html.button [ Events.onClick <| SendWS h ] [ text "add sel to playlist" ]
                , Html.button [ Events.onClick <| replaceAndPlay h ] [ text "play sel" ]
                ]

    -- [ Html.a [ Attr.title "add to playlist"] [ icon_add Color.black 24 ]
    -- , Html.a [ Attr.title "replace playlist with ..." ] [ icon_replace Color.black 24 ]
    -- ]
    ]


viewPlaylist : Model -> Html Msg
viewPlaylist model =
    let
        col cl txt =
            div [ Attr.class cl ] [ txt ]
    in
    div [ Attr.class "playlistwrap" ]
        [ div [ Attr.class "playlist" ]
            (List.map
                (\e ->
                    let
                        current =
                            case model.status of
                                Nothing ->
                                    False

                                Just s ->
                                    s.songid == e.id

                        t =
                            e.track

                        track =
                            if current && Maybe.map .state model.status == Just "play" then
                                icon_play Color.black 16

                            else if current && Maybe.map .state model.status == Just "pause" then
                                icon_pause Color.black 16

                            else
                                text t.track
                    in
                    div
                        [ Attr.class
                            (if current then
                                "current"

                             else
                                ""
                            )
                        , Events.onDoubleClick <| pressPlayID e.id
                        ]
                        [ col "track" track
                        , col "title" <| text t.title
                        , col "artist" <| text t.artist
                        , col "album" <| text t.album
                        , col "dur" <| text <| prettySecs t.duration
                        ]
                )
                model.playlist
            )
        , div [ Attr.class "commands" ]
            [ button [ Events.onClick <| pressClear ] [ text "clear playlist" ]
            ]
        , viewPlayer model
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    case ( model.conn, model.mpdOnline ) of
        ( Just _, True ) ->
            Time.every Time.second Tick

        _ ->
            Sub.none


wsSend : Maybe Explicit.WebSocket -> String -> Cmd Msg
wsSend mconn o =
    case mconn of
        Nothing ->
            Debug.log "sending without connection" Cmd.none

        Just conn ->
            Explicit.send conn o (\err -> Debug.log ("msg err: " ++ err) Noop)


cmdLoadDir : String -> String -> String
cmdLoadDir id dir =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "loaddir" )
            , ( "id", Encode.string id )
            , ( "file", Encode.string dir )
            ]


cmdPlay : String
cmdPlay =
    buildWsCmd "play"


pressPlay : Msg
pressPlay =
    SendWS cmdPlay


cmdStop : String
cmdStop =
    buildWsCmd "stop"


pressStop : Msg
pressStop =
    SendWS cmdStop


cmdPause : String
cmdPause =
    buildWsCmd "pause"


pressPause : Msg
pressPause =
    SendWS cmdPause


cmdClear : String
cmdClear =
    buildWsCmd "clear"


pressClear : Msg
pressClear =
    SendWS cmdClear


pressPlayID : String -> Msg
pressPlayID id =
    SendWS <| buildWsCmdID "playid" id


pressPrevious : Msg
pressPrevious =
    SendWS <| buildWsCmd "previous"


pressNext : Msg
pressNext =
    SendWS <| buildWsCmd "next"


cmdPlaylistAdd : String -> String
cmdPlaylistAdd id =
    buildWsCmdID "add" id


cmdSeek : String -> Float -> String
cmdSeek id seconds =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "seek" )
            , ( "song", Encode.string id )
            , ( "seconds", Encode.float seconds )
            ]


cmdSetVolume : Float -> String
cmdSetVolume v =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "volume" )
            , ( "volume", Encode.float v )
            ]


cmdList : String -> String -> String -> String -> String
cmdList id what artist album =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "list" )
            , ( "id", Encode.string id )
            , ( "what", Encode.string what )
            , ( "artist", Encode.string artist )
            , ( "album", Encode.string album )
            ]


cmdTrack : String -> String -> String
cmdTrack id file =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "track" )
            , ( "id", Encode.string id )
            , ( "file", Encode.string file )
            ]


replaceAndPlay : String -> Msg
replaceAndPlay v =
    SendWS <|
        cmdClear
            ++ v
            ++ cmdPlay


cmdFindAdd : String -> String -> String -> String
cmdFindAdd artist album track =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "findadd" )
            , ( "artist", Encode.string artist )
            , ( "album", Encode.string album )
            , ( "track", Encode.string track )
            ]


buildWsCmd : String -> String
buildWsCmd cmd =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string cmd )
            ]


buildWsCmdID : String -> String -> String
buildWsCmdID cmd id =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string cmd )
            , ( "id", Encode.string id )
            ]


setFilePane : String -> List Mpd.Inode -> List MPane -> List MPane
setFilePane paneid inodes panes =
    let
        body =
            Pane.Entries <| toFilePaneEntries paneid inodes
    in
    Pane.setBody body paneid panes


toFilePaneEntries : String -> List Mpd.Inode -> List (Pane.Entry Msg)
toFilePaneEntries paneid inodes =
    let
        entry e =
            case e of
                Mpd.Dir id title ->
                    let
                        pid =
                            "dir" ++ id
                    in
                    Pane.Entry pid
                        title
                        (Just <|
                            AddFilePane paneid <|
                                Pane.newPane pid title (cmdLoadDir pid id)
                        )
                        (Just <| cmdPlaylistAdd id)

                Mpd.File id name ->
                    let
                        pid =
                            "dir" ++ id
                    in
                    Pane.Entry pid
                        name
                        (Just <| AddFilePane paneid (filePane pid id name))
                        (Just <| cmdPlaylistAdd id)
    in
    List.map entry inodes


setListPane : String -> List Mpd.DBEntry -> List MPane -> List MPane
setListPane paneid db panes =
    let
        body =
            Pane.Entries <| toListPaneEntries paneid db
    in
    Pane.setBody body paneid panes


toListPaneEntries : String -> List Mpd.DBEntry -> List (Pane.Entry Msg)
toListPaneEntries parentid ls =
    let
        entry e =
            case e of
                Mpd.DBArtist artist ->
                    let
                        id =
                            "artist" ++ artist

                        add =
                            cmdFindAdd artist "" ""
                    in
                    Pane.Entry id
                        artist
                        (Just <|
                            AddArtistPane
                                parentid
                                (Pane.newPane id artist (cmdList id "artistalbums" artist ""))
                        )
                        (Just add)

                Mpd.DBAlbum artist album ->
                    let
                        id =
                            "album" ++ artist ++ album

                        add =
                            cmdFindAdd artist album ""
                    in
                    Pane.Entry id
                        album
                        (Just <|
                            AddArtistPane
                                parentid
                                (Pane.newPane id album (cmdList id "araltracks" artist album))
                        )
                        (Just add)

                Mpd.DBTrack artist album title id track ->
                    let
                        pid =
                            "track" ++ id

                        -- TODO: use "add file" ?
                        add =
                            cmdFindAdd artist album title
                    in
                    Pane.Entry pid
                        (track ++ " " ++ title)
                        (Just <|
                            AddArtistPane
                                parentid
                                (filePane pid id title)
                        )
                        (Just add)
    in
    List.map entry ls


setTrackPane : String -> Mpd.Track -> List MPane -> List MPane
setTrackPane paneid track panes =
    let
        body =
            Pane.Plain <| toPane track
    in
    Pane.setBody body paneid panes


reloadFiles : Model -> Cmd Msg
reloadFiles m =
    Cmd.batch <|
        List.map (\p -> wsSend m.conn p.update) m.fileView


reloadArtists : Model -> Cmd Msg
reloadArtists m =
    Cmd.batch <|
        List.map (\p -> wsSend m.conn p.update) m.artistView


scrollNC : Cmd Msg
scrollNC =
    Task.attempt (\_ -> Noop) <| Scroll.toRight "nc"


prettySecs : Float -> String
prettySecs secsf =
    let
        secs =
            round secsf

        m =
            secs // 60

        s =
            secs % 60
    in
    toString m ++ ":" ++ (String.padLeft 2 '0' <| toString s)


filePane : String -> String -> String -> MPane
filePane paneid fileid name =
    let
        p =
            Pane.newPane paneid name (cmdTrack paneid fileid)

        body : Pane.Body Msg
        body =
            Pane.Plain <| Html.text "..."
    in
    { p | body = body }


toPane : Mpd.Track -> Html Msg
toPane t =
    Html.div []
        [ FontAwesome.music Color.black 12
        , text <| " " ++ t.title
        , Html.br [] []
        , text <| "artist: " ++ t.artist
        , Html.br [] []
        , text <| "album: " ++ t.album
        , Html.br [] []
        , text <| "track: " ++ t.track
        , Html.br [] []
        , text <| "duration: " ++ prettySecs t.duration
        , Html.br [] []
        ]
