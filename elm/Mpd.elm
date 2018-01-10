module Mpd exposing
    ( Status
    , newStatus
    , Track
    , Playlist
    , Inodes
    , Inode (..)
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
    , time : String
    , elapsed : String
    }

newStatus : Status
newStatus = {state="", songid="", time="", elapsed=""}

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
        , file = ""
        , artist = ""
        , album = ""
        , title = ""
        }

type alias Inodes =
    { id : String
    , inodes : List Inode
    }

type Inode
    = Dir String String -- id, "name"
    | File String String -- id, "name"

type WSMsg
    = WSStatus Status
    | WSPlaylist Playlist
    | WSInode Inodes

wsMsgDecoder : Decode.Decoder WSMsg
wsMsgDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen (\t ->
            case t of
                "status" -> Decode.field "msg" (Decode.map WSStatus statusDecoder)
                "playlist" -> Decode.field "msg" (Decode.map WSPlaylist playlistDecoder)
                "inodes" -> Decode.field "msg" (Decode.map WSInode inodesDecoder)
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

inodeDecoder : Decode.Decoder Inode
inodeDecoder =
    Decode.oneOf
        -- TODO: also skip the empty dir
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
