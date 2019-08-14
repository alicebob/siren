module Main where

import Prelude

import Control.Monad.State (get, put)
import Control.Monad.Except (runExcept)
import Data.Maybe (Maybe(..))
import Data.Foldable (for_)
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Debug.Trace (traceM)
import Foreign (readString)

import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Aff (awaitBody)
import Halogen.VDom.Driver (runUI)
import Web.Event.EventTarget as EET
import Web.Socket.WebSocket as WS
import Web.Socket.Event.EventTypes as WSET
import Web.Socket.Event.MessageEvent as ME

data View
    = Playlist
    | FileBrowser
    | ArtistBrowser
derive instance eqView :: Eq View

type State = 
    { exampleButton :: Boolean
    , view :: View
    , mpdOnline :: Boolean
    }

initState :: State
initState =
    { exampleButton: false
    , view: Playlist
    , mpdOnline: false
    }

data Action
    = Toggle
    | Show View

toggleButton :: State -> H.ComponentHTML Action () Aff
toggleButton state =
  let toggleLabel = if state.exampleButton then "ON" else "OFF"
  in
    HH.button
      [ HE.onClick \_ -> Just Toggle ]
      [ HH.text $ "The button is " <> toggleLabel ]

viewPage :: State -> H.ComponentHTML Action () Aff
viewPage state =
    HH.div
      [ HP.classes [ HH.ClassName "mpd" ] ]
      [ viewHeader state
      , viewView state
      ]

viewHeader :: State -> H.ComponentHTML Action () Aff
viewHeader state =
    HH.nav_
        [ logo
        , HH.span_ []
        , tab Playlist "Playlist XXX" "Show current playlist"
        , tab FileBrowser "Files" "Browse the filesystem"
        , tab ArtistBrowser "Artists" "Browse by artist"
        , HH.span_ []
        , status
        ]
    where
        logo =
            HH.a
                [ HP.classes [ HH.ClassName "logo" ] ]
                [ HH.a
                    [ HE.onClick \_ -> Just $ Show Playlist ]
                    [ HH.text "Siren!" ]
                ]
        tab view text title =
            HH.a
                [ HE.onClick \_ -> Just $ Show view
                , HP.classes
                    [ HH.ClassName "tab"
                    , HH.ClassName $ if state.view == view then "current" else "inactive"
                    ]
                , HP.title title
                ]
                [ HH.text text ]
        statusClass  =
            case state.mpdOnline of
                false -> "offline"
                true -> "online"
        statusTitle =
            case state.mpdOnline of
                false -> "Offline"
                true -> "Online"
        status =
            HH.a
                [ HP.classes
                    [ HH.ClassName "status"
                    , HH.ClassName statusClass
                    ]
                , HP.title statusTitle
                ]
                [ HH.text statusTitle ]

viewView :: State -> H.ComponentHTML Action () Aff
viewView state =
    case state.view of
        Playlist ->
            viewPlaylist state
        FileBrowser ->
            viewExample state
        ArtistBrowser ->
            viewExample state

viewExample :: State -> H.ComponentHTML Action () Aff
viewExample = toggleButton

viewPlaylist :: State -> H.ComponentHTML Action () Aff
viewPlaylist state =
    wrap
      [ HH.div
        [ HP.classes [ HH.ClassName "playlist" ] ]
        [ HH.div
            [ HP.classes [ HH.ClassName "commands" ] ]
            [ HH.text "CLEAR PLAYLIST" ]
        , HH.div
            [ HP.classes [ HH.ClassName "header" ] ]
            [ col "track" "Track"
            , col "title" "Title"
            , col "artist" "Artist"
            , col "album" "Album"
            , col "dur" ""
            ]
        ]
      ]
    where
        wrap d =
            HH.div
                [ HP.classes [ HH.ClassName "playlistwrap" ] ]
                d
        col cl txt =
            HH.div
                [ HP.classes [ HH.ClassName cl ] ]
                [ HH.text txt ]

handleAction :: Action -> H.HalogenM State Action () Void Aff Unit
handleAction = case _ of
  Toggle -> do
    oldState <- get
    let newState = oldState { exampleButton = not oldState.exampleButton }
    put newState
  Show view -> do
    oldState <- get
    let newState = oldState { view = view }
    put newState


main :: Effect Unit
main = do
    createSocket "ws://localhost:6601/mpd/ws" traceM
    launchAff_ do
        body <- awaitBody
        runUI comp unit body
    where
        comp =
              H.mkComponent
                    { initialState: const initState
                    , render: viewPage
                    , eval: H.mkEval $ H.defaultEval { handleAction = handleAction }
                    }


-- taken from https://github.com/nwolverson/purerl-ws-demo/blob/master/client/src/WsDemo/Socket.purs
createSocket :: String -> (String -> Effect Unit) -> Effect Unit
createSocket url cb = do
    socket <- WS.create url []
    listener <- EET.eventListener \ev ->
        for_ (ME.fromEvent ev) \msgEvent ->
            for_ (runExcept $ readString $ ME.data_ msgEvent) cb
    EET.addEventListener WSET.onMessage listener false (WS.toEventTarget socket)
