module Log where

import Prelude

import Data.Array as A
import Data.Maybe (Maybe(..))
import Effect.Class (class MonadEffect)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Web.Event.Event (Event)
import Web.Event.Event as Event
import Debug.Trace (traceM)
import Math as Math

import MPD as MPD

data View
    = Playlist
    | FileBrowser
    | ArtistBrowser
derive instance eqView :: Eq View

type Slot = H.Slot Query Message

data Query a =
        ReceiveMessage String a
        | CmdConnection Boolean a
        | CmdConfig MPDConfig a
        | CmdPlaylist MPD.Playlist a

data Message = OutputMessage String

data Action
  = HandleInput String
  | Submit Event
  | Show View

type State =
  { messages :: Array String
  , inputText :: String
  , view :: View
  , mpdOnline :: Boolean
  , config :: Maybe MPDConfig
  , playlist :: MPD.Playlist
  }

type MPDConfig =
  { artistmode :: Int
  , mpdhost :: String
  }

component :: forall i m. MonadEffect m => H.Component HH.HTML Query i Message m
component =
  H.mkComponent
    { initialState
    , render: viewPage
    , eval: H.mkEval $ H.defaultEval
        { handleAction = handleAction
        , handleQuery = handleQuery
        }
    }

initialState :: forall i. i -> State
initialState _ =
        { messages: []
        , inputText: ""
        , view: Playlist
        , mpdOnline: false
        , config: Nothing
        , playlist: []
        }

viewPage :: forall m. State -> H.ComponentHTML Action () m
viewPage state =
    HH.div
      [ HP.classes [ HH.ClassName "mpd" ] ]
      [ viewHeader state
      , viewView state
      ]


viewHeader :: forall m. State -> H.ComponentHTML Action () m
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


viewView :: forall m. State -> H.ComponentHTML Action () m
viewView state =
    case state.view of
        Playlist ->
            viewPlaylist state
        FileBrowser ->
            render state
        ArtistBrowser ->
            render state

viewPlaylist :: forall m. State -> H.ComponentHTML Action () m
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
      , HH.div
        [ HP.classes [ HH.ClassName "entries" ] ]
        (map (\e ->
            HH.div
                [ HP.classes [ HH.ClassName "entry" ] ]
                [ col "track" $ e.track.track
                , col "title" $ e.track.title
                , col "artist" $ e.track.artist
                , col "album" $ e.track.album
                , col "dur" $ prettySecs e.track.duration
                ]
        ) state.playlist)
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




render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.form
    [ HE.onSubmit (Just <<< Submit) ]
    [ HH.ol_ $ map (\msg -> HH.li_ [ HH.text msg ]) state.messages
    , HH.input
        [ HP.type_ HP.InputText
        , HP.value (state.inputText)
        , HE.onValueInput (Just <<< HandleInput)
        ]
    , HH.button
        [ HP.type_ HP.ButtonSubmit ]
        [ HH.text "Send Message" ]
    ]

handleAction :: forall m. MonadEffect m => Action -> H.HalogenM State Action () Message m Unit
handleAction = case _ of
  HandleInput text -> do
    H.modify_ (_ { inputText = text })
  Submit ev -> do
    H.liftEffect $ Event.preventDefault ev
    st <- H.get
    let outgoingMessage = st.inputText
    H.raise $ OutputMessage outgoingMessage
    H.modify_ \st' -> st'
      { messages = st'.messages `A.snoc` ("Sending: " <> outgoingMessage)
      , inputText = ""
      }
  Show view -> do
    H.modify_ (_ { view = view })


handleQuery :: forall m a. Query a -> H.HalogenM State Action () Message m (Maybe a)
handleQuery = case _ of
  ReceiveMessage msg a -> do
    let incomingMessage = "Received: " <> msg
    traceM incomingMessage
    H.modify_ \st -> st { messages = st.messages `A.snoc` incomingMessage }
    pure (Just a)
  CmdConnection connected a -> do
    H.modify_ \st -> st { mpdOnline = connected }
    pure (Just a)
  CmdConfig c a -> do
    H.modify_ \st -> st { config = Just c }
    pure (Just a)
  CmdPlaylist p a -> do
    H.modify_ \st -> st { playlist = p }
    pure (Just a)


prettySecs :: Number -> String
prettySecs secsf =
    let
        secs =
            Math.round secsf

        m =
            Math.floor $ secs / 60.0

        s =
            Math.remainder secs 60.0
    in
    show m <> ":" <> show s

