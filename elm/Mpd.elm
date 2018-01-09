module Mpd exposing
    ( Status
    , newStatus
    , Track
    , Playlist
    , newPlaylist
    , WSMsg (..)
    , wsMsgDecoder
    )

import Json.Decode as Decode


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
