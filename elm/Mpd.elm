module Mpd exposing
    ( Status
    , newStatus
    , Track
    , Playlist
    , Inodes
    , Inode (..)
    , DBList
    , DBEntry (..)
    , newPlaylist
    , lookupPlaylist
    , WSMsg (..)
    , wsMsgDecoder
    )

import Json.Decode as Decode

type alias SongId = String

type alias Status =
    { state : String -- "play", ...
    , songid : SongId
    , elapsed : Float
    , duration : Float
    }

newStatus : Status
newStatus = {state="", songid="", elapsed=0, duration=0}

type alias Track =
    { id : SongId
    , file : String
    , artist : String
    , album : String
    , title : String
    }

type alias Playlist = List Track

newPlaylist : Playlist
newPlaylist = []

lookupPlaylist : Playlist -> SongId -> Track
lookupPlaylist ts id = ts
    |> List.filter (\ t -> t.id == id )
    |> List.head
    |> Maybe.withDefault
        { id = id
        , file = "unknown.mp3"
        , artist = "Unknown Artist"
        , album = "Unknown Album"
        , title = "Unknown Title"
        }

type alias Inodes =
    { id : String
    , inodes : List Inode
    }

type Inode
    = Dir String String -- id, "name"
    | File String String -- id, "name"

type DBEntry
    = DBArtist String -- artist
    | DBAlbum String String -- artist album
    | DBTrack String String String -- artist album title

type alias DBList =
    { id : String
    , list : List DBEntry
    }

type WSMsg
    = WSStatus Status
    | WSPlaylist Playlist
    | WSInode Inodes
    | WSList DBList

wsMsgDecoder : Decode.Decoder WSMsg
wsMsgDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen (\t ->
            case t of
                "status" -> Decode.field "msg" (Decode.map WSStatus statusDecoder)
                "playlist" -> Decode.field "msg" (Decode.map WSPlaylist playlistDecoder)
                "inodes" -> Decode.field "msg" (Decode.map WSInode inodesDecoder)
                "list" -> Decode.field "msg" (Decode.map WSList dblistDecoder)
                _  -> Debug.crash("unknown type field")
        )

decodeFloatString : Decode.Decoder Float
decodeFloatString = Decode.string
    |> Decode.andThen (\ s ->
        case Decode.decodeString Decode.float s of
            Ok r -> Decode.succeed r
            Err e -> Decode.fail e)

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
    Decode.map5
      Track
      (Decode.field "id" Decode.string)
      (Decode.field "file" Decode.string)
      (Decode.field "artist" Decode.string)
      (Decode.field "album" Decode.string)
      (Decode.field "title" Decode.string)

playlistDecoder : Decode.Decoder Playlist
playlistDecoder = Decode.list trackDecoder

inodeDecoder : Decode.Decoder Inode
inodeDecoder =
    Decode.oneOf
        -- TODO: also skip when "dir" is empty
        [ Decode.map2
          Dir
          (Decode.field "id" Decode.string)
          (Decode.field "dir" Decode.string)
        , Decode.map2
          File
          (Decode.field "id" Decode.string)
          (Decode.field "file" Decode.string)
        ]

inodesDecoder : Decode.Decoder Inodes
inodesDecoder =
    Decode.map2
        Inodes
        (Decode.field "id" Decode.string)
        (Decode.field "inodes" (Decode.list inodeDecoder))

dblistDecoder : Decode.Decoder DBList
dblistDecoder =
    Decode.map2
        DBList
        (Decode.field "id" Decode.string)
        (Decode.field "list" <| Decode.list dbentryDecoder)

dbentryDecoder : Decode.Decoder DBEntry
dbentryDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen (\t -> case t of
            "artist" -> Decode.map DBArtist
                            (Decode.field "artist" Decode.string)
            "album" -> Decode.map2 DBAlbum
                            (Decode.field "artist" Decode.string)
                            (Decode.field "album" Decode.string)
            "track" -> Decode.map3 DBTrack
                            (Decode.field "artist" Decode.string)
                            (Decode.field "album" Decode.string)
                            (Decode.field "title" Decode.string)
            _  -> Debug.crash("unknown type field")
        )
