module Pane exposing 
    ( Pane
    , Entry
    , Body (..)
    , newPane
    , addPane
    , setBody
    )

import Html exposing (Html)

type alias Entry a =
    { id : String
    , title : String
    , onClick : Maybe a -- Msg
    , selection : Maybe String -- "add to playlist" JSON
    }


type Body a
    = Plain (Html a)
    | Entries (List (Entry a))

type alias Pane a =
    { id : String
    , title : String
    , body : Body a
    -- , entries : List (Entry a)
    , current : Maybe String -- selected entry -- FIXME: will go into Entry
    , update : String -- payload to update the content
    }


newPane : String -> String -> String -> Pane a
newPane id title update =
    { id = id
    , title = title
    , update = update
    , body = Entries []
    , current = Nothing
    }


addPane : List (Pane a) -> String -> Pane a -> List (Pane a)
addPane panes after new =
    case panes of
        [] ->
            []

        p :: tail ->
            if p.id == after then
                { p | current = Just new.id } :: [ new ]
            else
                p :: addPane tail after new


setBody : Body a -> String -> List (Pane a) -> List (Pane a)
setBody body paneid panes =
    case panes of
        [] ->
            []

        p :: tail ->
            if p.id == paneid then
                { p | body = body } :: tail
            else
                p :: setBody body paneid tail
