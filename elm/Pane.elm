module Pane
    exposing
        ( Body(..)
        , Entry
        , Pane
        , addPane
        , loading
        , new
        , update
        )

import Html exposing (Html)


type alias Entry a =
    { id : String
    , title : String
    , onClick : Maybe a -- Msg
    , selection : Maybe String -- "add to playlist" JSON
    }



-- body styles:
-- entries: drop shadow, full height.
-- text: blue background, no drop shadow, used as last pane only


type Body a
    = Info
        { body : Maybe (List (Html a)) -- when Nothing it's loading
        , footer : List (Html a)
        }
    | Entries
        { title : String
        , entries : Maybe (List (Entry a)) -- when nothing it's loading
        , footer : List (Html a)
        }


type alias Pane a =
    { id : String
    , body : Body a -- also defined the style of pane
    , update : String -- payload to update the content
    }


new : String -> Body a -> String -> Pane a
new id body update =
    { id = id
    , body = body
    , update = update
    }


loading : String -> Body a
loading title =
    Entries
        { title = title
        , entries = Nothing
        , footer = []
        }


addPane : List (Pane a) -> String -> Pane a -> List (Pane a)
addPane panes after new =
    case panes of
        [] ->
            []

        p :: tail ->
            if p.id == after then
                p :: [ new ]

            else
                p :: addPane tail after new



-- update a pane by ID


update : (Body a -> Body a) -> String -> List (Pane a) -> List (Pane a)
update f paneid panes =
    case panes of
        [] ->
            []

        p :: tail ->
            if p.id == paneid then
                { p | body = f p.body } :: tail

            else
                p :: update f paneid tail
