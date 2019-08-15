module Main where

import Prelude

import Control.Coroutine as CR
import Control.Coroutine.Aff (emit)
import Control.Coroutine.Aff as CRA
import Control.Monad.Except (runExcept)
import Data.Either (either, Either(..))
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Foreign as FR
import Foreign (F, Foreign, unsafeToForeign, readString)
import Halogen as H
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.Event.EventTarget as EET
import Web.Socket.Event.EventTypes as WSET
import Web.Socket.Event.MessageEvent as ME
import Web.Socket.WebSocket as WS
import Simple.JSON as JSON

import Log as Log

-- A producer coroutine that emits messages that arrive from the websocket.
wsProducer :: WS.WebSocket -> CR.Producer String Aff Unit
wsProducer socket = CRA.produce \emitter -> do
  listener <- EET.eventListener \ev -> do
    for_ (ME.fromEvent ev) \msgEvent ->
      for_ (readHelper readString (ME.data_ msgEvent)) \msg ->
        emit emitter msg
  EET.addEventListener
    WSET.onMessage
    listener
    false
    (WS.toEventTarget socket)
  where
    readHelper :: forall a b. (Foreign -> F a) -> b -> Maybe a
    readHelper read =
      either (const Nothing) Just <<< runExcept <<< read <<< unsafeToForeign

-- A consumer coroutine that takes the `query` function from our component IO
-- record and sends `ReceiveMessage` queries in when it receives inputs from the
-- producer.
wsConsumer :: (forall a. Log.Query a -> Aff (Maybe a)) -> CR.Consumer String Aff Unit
wsConsumer query = CR.consumer \msg -> do
  void $ query $ H.tell $ parsePayload msg
  pure Nothing

-- A consumer coroutine that takes output messages from our component IO
-- and sends them using the websocket
wsSender :: WS.WebSocket -> CR.Consumer Log.Message Aff Unit
wsSender socket = CR.consumer \msg -> do
  case msg of
    Log.OutputMessage msgContents ->
      liftEffect $ WS.sendString socket msgContents
  pure Nothing

type MessageEnvelope =
  { tagname :: String
  , value :: Foreign
  }

parsePayload :: forall a. String -> a -> Log.Query a
parsePayload msg =
    case JSON.readJSON msg of 
        Right (r :: MessageEnvelope) ->
            case r.tagname of
                "siren/connection" ->
                    case runExcept (FR.readBoolean r.value) of
                        Right (c :: Boolean) ->
                            Log.CmdConnection c
                        Left e ->
                            Log.ReceiveMessage ("parse failed: " <> show e)
                _ -> Log.ReceiveMessage msg
        Left e ->
            Log.ReceiveMessage ("parse failed: " <> show e)

main :: Effect Unit
main = do
  connection <- WS.create "ws://localhost:6601/mpd/ws" []
  HA.runHalogenAff do
    body <- HA.awaitBody
    io <- runUI Log.component unit body

    -- The wsSender consumer subscribes to all output messages
    -- from our component
    io.subscribe $ wsSender connection

    -- Connecting the consumer to the producer initializes both,
    -- feeding queries back to our component as messages are received.
    CR.runProcess (wsProducer connection CR.$$ wsConsumer io.query)

