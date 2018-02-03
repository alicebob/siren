module Mpd
    exposing
        ( DBEntry(..)
        , Inode(..)
        , Playlist
        , Status
        , Track
        , WSMsg(..)
        , lookupPlaylist
        , newPlaylist
        , newStatus
        , wsMsgDecoder
        )

import Decode


type alias SongId =
    String


type alias Status =
    { state : String -- "play", ...
    , songid : SongId
    , elapsed : Float
    , duration : Float
    }


newStatus : Status
newStatus =
    { state = "", songid = "", elapsed = 0, duration = 0 }


type alias Track =
    { id : SongId -- whole path
    , file : String -- just the filename
    , artist : String
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
    | DBTrack String String String String String -- artist album title id tracknr


type WSMsg
    = WSStatus Status
    | WSPlaylist Playlist
    | WSInode String (List Inode)
    | WSList String (List DBEntry)
    | WSTrack String Track
    | WSDatabase


byField : String -> List ( String, Decode.Decoder a ) -> Decode.Decoder a
byField field decoders =
    let
        lookup key kvs =
            case kvs of
                ( k, v ) :: rest ->
                    if k == key then
                        Just v
                    else
                        lookup key rest

                [] ->
                    Nothing
    in
    Decode.field field Decode.string
        |> Decode.andThen
            (\t ->
                case lookup t decoders of
                    Just d ->
                        d

                    Nothing ->
                        Decode.fail <| "type not found: " ++ t
            )


wsMsgDecoder : Decode.Decoder WSMsg
wsMsgDecoder =
    byField "type"
        [ ( "status", Decode.field "msg" <| Decode.map WSStatus statusDecoder )
        , ( "playlist", Decode.field "msg" <| Decode.map WSPlaylist playlistDecoder )
        , ( "inodes"
          , Decode.map2
                WSInode
                (Decode.field "id" Decode.string)
                (Decode.field "msg" <| Decode.anyList inodeDecoder)
          )
        , ( "list"
          , Decode.map2
                WSList
                (Decode.field "id" Decode.string)
                (Decode.field "msg" <| Decode.anyList dbentryDecoder)
          )
        , ( "track"
          , Decode.map2
                WSTrack
                (Decode.field "id" Decode.string)
                (Decode.field "msg" trackDecoder)
          )
        , ( "database", Decode.succeed WSDatabase )
        ]


decodeFloatString : Decode.Decoder Float
decodeFloatString =
    Decode.string
        |> Decode.andThen
            (\s ->
                if s == "" then
                    Decode.succeed 0
                else
                    case Decode.decodeString Decode.float s of
                        Ok r ->
                            Decode.succeed r

                        Err e ->
                            Decode.fail e
            )


statusDecoder : Decode.Decoder Status
statusDecoder =
    Decode.map4
        Status
        (Decode.field "state" Decode.string)
        (Decode.field "songid" Decode.string)
        (Decode.field "elapsed" decodeFloatString)
        (Decode.field "duration" decodeFloatString)


trackDecoder : Decode.Decoder Track
trackDecoder =
    Decode.map7
        Track
        (Decode.field "id" Decode.string)
        (Decode.field "file" Decode.string)
        (Decode.field "artist" Decode.string)
        (Decode.field "album" Decode.string)
        (Decode.field "track" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "duration" decodeFloatString)


playlistDecoder : Decode.Decoder Playlist
playlistDecoder =
    Decode.anyList <|
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
    byField "type"
        [ ( "artist"
          , Decode.map DBArtist
                (Decode.field "artist" Decode.string)
          )
        , ( "album"
          , Decode.map2 DBAlbum
                (Decode.field "artist" Decode.string)
                (Decode.field "album" Decode.string)
          )
        , ( "track"
          , Decode.map5 DBTrack
                (Decode.field "artist" Decode.string)
                (Decode.field "album" Decode.string)
                (Decode.field "title" Decode.string)
                (Decode.field "id" Decode.string)
                (Decode.field "track" Decode.string)
          )
        ]
