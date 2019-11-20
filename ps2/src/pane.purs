module Pane where

import Data.Maybe (Maybe)
import Halogen.HTML as HH

type Pane =
  { id :: String
  , body :: Body
  , update :: String
  }

data Body
    = Info { body :: Maybe HH.PlainHTML }
    | Entries { title :: String }

new :: String -> Body -> String -> Pane
new id body update =
    { id: id
    , body: body
    , update: update
    }

loading :: String -> Body
loading title =
    Entries {title: title}
  
