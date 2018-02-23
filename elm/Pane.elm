module Pane
    exposing
        ( Body(..)
        , Entry
        , Kind(..)
        , Pane
        , addPane
        , newPane
        , update
        )

import Html exposing (Html)


type Kind
    = Normal -- drop shadow, full height.
    | End -- blue background, no drop shadow, used as last pane only


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
    { kind : Kind
    , id : String
    , title : String
    , body : Body a
    , footer : List (Html a)
    , current : Maybe String -- selected entry
    , update : String -- payload to update the content
    }


newPane : Kind -> String -> String -> List (Html a) -> String -> Pane a
newPane kind id title footer update =
    { kind = kind
    , id = id
    , title = title
    , body = Entries []
    , footer = footer
    , update = update
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



-- update a pane by ID


update : (Pane a -> Pane a) -> String -> List (Pane a) -> List (Pane a)
update f paneid panes =
    case panes of
        [] ->
            []

        p :: tail ->
            if p.id == paneid then
                f p :: tail

            else
                p :: update f paneid tail
