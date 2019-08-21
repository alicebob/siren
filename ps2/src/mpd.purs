module MPD where


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

