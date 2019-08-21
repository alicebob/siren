module MPD where

import Simple.JSON as JSON
import Foreign ( Foreign)

type SongId =
  String

type Track =
  { id :: SongId
  , file :: String
  , album :: String
  , albumartist :: String
  , artist :: String
  , track :: String
  , title :: String
  , duration :: Number
  }

type PlaylistTrack =
  { id :: String
  , pos :: Int
  , track :: Track
  }

type Playlist =
  Array PlaylistTrack

data Cmd =
    CmdPlayID String


type MessageEnvelope =
  { tagname :: String
  , value :: Foreign
  }

enc :: Cmd -> String
enc c =
    JSON.writeJSON b    
  where
    b :: MessageEnvelope
    b = case c of CmdPlayID id ->
        { tagname: "playid"
        , value: JSON.write {id: id}
        }
