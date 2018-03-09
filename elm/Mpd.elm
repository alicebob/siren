module Mpd
    exposing
        ( ArtistMode(..)
        , Config
        , DBEntry(..)
        , Inode(..)
        , Playlist
        , Status
        , Track
        , WSCmd(..)
        , WSMsg(..)
        , encodeCmd
        , lookupPlaylist
        , newPlaylist
        , wsMsgDecoder
        )

import Decode
import Encode


type alias SongId =
    String


type ArtistMode
    = Artist
    | Albumartist


type alias Config =
    { artistMode : ArtistMode
    , mpdHost : String
    }


type alias Status =
    { state : String -- "play", ...
    , songid : SongId
    , elapsed : Float
    , duration : Float
    , volume : Float
    }


type alias Track =
    { id : SongId -- whole path
    , file : String -- just the filename
    , artist : String
    , albumartist : String
    , album : String
    , track : String
    , title : String
    , duration : Float
    }


type alias PlaylistTrack =
    { id : String
    , pos : Int
    , track : Track
    }


type alias Playlist =
    List PlaylistTrack


newPlaylist : Playlist
newPlaylist =
    []


lookupPlaylist : Playlist -> SongId -> Track
lookupPlaylist ts id =
    let
        pt =
            ts
                |> List.filter (\t -> t.id == id)
                |> List.head
    in
    case pt of
        Nothing ->
            { id = ""
            , file = "unknown.mp3"
            , artist = "Unknown Artist"
            , albumartist = "Unknown Artist"
            , album = "Unknown Album"
            , track = "00"
            , title = "Unknown Title"
            , duration = 0.0
            }

        Just t ->
            t.track


type Inode
    = Dir String String -- id, title
    | File String String -- id, title


type DBEntry
    = DBArtist String -- artist
    | DBAlbum String String -- artist album
    | DBTrack Track


type WSMsg
    = WSConfig Config
    | WSConnection Bool
    | WSStatus Status
    | WSPlaylist Playlist
    | WSInode String (List Inode)
    | WSList ArtistMode String (List DBEntry)
    | WSTrack String Track
    | WSDatabase


wsMsgDecoder : Decode.Decoder WSMsg
wsMsgDecoder =
    Decode.tagged
        [ ( "siren/config", Decode.map WSConfig configDecoder )
        , ( "siren/connection", Decode.map WSConnection Decode.bool )
        , ( "siren/status", Decode.map WSStatus statusDecoder )
        , ( "siren/playlist", Decode.map WSPlaylist playlistDecoder )
        , ( "siren/inodes"
          , Decode.map2
                WSInode
                (Decode.field "id" Decode.string)
                (Decode.field "inodes" <| Decode.vector inodeDecoder)
          )
        , ( "siren/list"
          , Decode.map3
                WSList
                (Decode.field "artistmode" modeDecoder)
                (Decode.field "id" Decode.string)
                (Decode.field "list" <| Decode.vector dbentryDecoder)
          )
        , ( "siren/track"
          , Decode.map2
                WSTrack
                (Decode.field "id" Decode.string)
                (Decode.field "track" trackDecoder)
          )
        , ( "siren/database", Decode.succeed WSDatabase )
        ]


statusDecoder : Decode.Decoder Status
statusDecoder =
    Decode.map5
        Status
        (Decode.field "state" Decode.string)
        (Decode.field "songid" Decode.string)
        (Decode.field "elapsed" Decode.float)
        (Decode.field "duration" Decode.float)
        (Decode.field "volume" Decode.float)


configDecoder : Decode.Decoder Config
configDecoder =
    Decode.map2
        Config
        (Decode.field "artistmode" modeDecoder)
        (Decode.field "mpdhost" Decode.string)


trackDecoder : Decode.Decoder Track
trackDecoder =
    Decode.map8
        Track
        (Decode.field "id" Decode.string)
        (Decode.field "file" Decode.string)
        (Decode.field "artist" Decode.string)
        (Decode.field "albumartist" Decode.string)
        (Decode.field "album" Decode.string)
        (Decode.field "track" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "duration" Decode.float)


playlistDecoder : Decode.Decoder Playlist
playlistDecoder =
    Decode.vector <|
        Decode.map3
            PlaylistTrack
            (Decode.field "id" Decode.string)
            (Decode.field "pos" Decode.int)
            (Decode.field "track" trackDecoder)


inodeDecoder : Decode.Decoder Inode
inodeDecoder =
    Decode.oneOf
        [ Decode.field "dir" <|
            Decode.map2
                Dir
                (Decode.field "id" Decode.string)
                (Decode.field "title" Decode.string)
        , Decode.field "file" <|
            Decode.map2
                File
                (Decode.field "id" Decode.string)
                (Decode.field "title" Decode.string)
        ]


dbentryDecoder : Decode.Decoder DBEntry
dbentryDecoder =
    Decode.tagged
        [ ( "siren/entry.artist"
          , Decode.map DBArtist
                (Decode.field "artist" Decode.string)
          )
        , ( "siren/entry.album"
          , Decode.map2 DBAlbum
                (Decode.field "artist" Decode.string)
                (Decode.field "album" Decode.string)
          )
        , ( "siren/entry.track"
          , Decode.map DBTrack trackDecoder
          )
        ]


modeDecoder : Decode.Decoder ArtistMode
modeDecoder =
    Decode.keyword
        |> Decode.andThen
            (\k ->
                case k of
                    "artist" ->
                        Decode.succeed Artist

                    "albumartist" ->
                        Decode.succeed Albumartist

                    _ ->
                        Decode.fail "wrong symbol"
            )


modeEncoder : ArtistMode -> Encode.Element
modeEncoder m =
    Encode.keyword <|
        case m of
            Artist ->
                Encode.mustKeyword "artist"

            Albumartist ->
                Encode.mustKeyword "albumartist"


type WSCmd
    = CmdPlay
    | CmdStop
    | CmdPause
    | CmdClear
    | CmdPlayID String
    | CmdPrevious
    | CmdNext
    | CmdPlaylistAdd String
    | CmdSeek String Float
    | CmdList String ArtistMode { what : String, artist : String, album : String }
    | CmdTrack String String
    | CmdFindAdd ArtistMode { artist : String, album : String, track : String }
    | CmdLoadDir String String
    | CmdSetVolume Float


encodeCmd : WSCmd -> String
encodeCmd cmd =
    let
        enc tag args =
            Encode.mustObject args
                |> Encode.mustTagged tag
                |> Encode.encode

        enc0 tag =
            enc tag []
    in
    case cmd of
        CmdPlay ->
            enc0 "play"

        CmdStop ->
            enc0 "stop"

        CmdPause ->
            enc0 "pause"

        CmdClear ->
            enc0 "clear"

        CmdPlayID id ->
            enc "playid"
                [ ( "id", Encode.string id ) ]

        CmdPrevious ->
            enc0 "previous"

        CmdNext ->
            enc0 "next"

        CmdPlaylistAdd id ->
            enc "add"
                [ ( "id", Encode.string id ) ]

        CmdSeek id seconds ->
            enc "seek"
                [ ( "song", Encode.string id )
                , ( "seconds", Encode.float seconds )
                ]

        CmdList id mode args ->
            enc "list"
                [ ( "id", Encode.string id )
                , ( "artistmode", modeEncoder mode )
                , ( "what", Encode.string args.what )
                , ( "artist", Encode.string args.artist )
                , ( "album", Encode.string args.album )
                ]

        CmdTrack id file ->
            enc "track"
                [ ( "id", Encode.string id )
                , ( "file", Encode.string file )
                ]

        CmdFindAdd mode q ->
            enc "findadd"
                [ ( "artistmode", modeEncoder mode )
                , ( "artist", Encode.string q.artist )
                , ( "album", Encode.string q.album )
                , ( "track", Encode.string q.track )
                ]

        CmdLoadDir id dir ->
            enc "loaddir"
                [ ( "id", Encode.string id )
                , ( "file", Encode.string dir )
                ]

        CmdSetVolume volume ->
            enc "volume"
                [ ( "volume", Encode.float volume )
                ]
