effect module Explicit
    where { command = WSCmd }
    exposing
        ( WebSocket
        , open
        , send
        )

{-| Explicit websocket handling.


# Example

    type alias Model =
        { websocket : Maybe WebSocket
        }

    type Msg
        = WSOpen (Result String WebSocket)
        | WSMessage String
        | WSClose String
        | WSSendingError String String

    update : Msg -> Model -> Model
    update msg model =
        case msg of
            WSOpen (Ok ws) ->
                ( { model | websocket = ws }, Cmd.none )
            WSOpen (Err err) ->
                ( model, Time.after Connect


# Basics

@docs WebSocket
@docs open, send

-}

import Task
import WebSocket.LowLevel as WSL


{-| An opaque websocket handle.
-}
type WebSocket
    = WS WSL.WebSocket


type WSCmd msg
    = Open String (Result String WebSocket -> msg) (String -> msg) (String -> msg)
    | Send WSL.WebSocket String (String -> msg)


cmdMap : (a -> b) -> WSCmd a -> WSCmd b
cmdMap f cmd =
    case cmd of
        Open a b c d ->
            Open a (f << b) (f << c) (f << d)

        Send a b c ->
            Send a b (f << c)


init : Task.Task Never ()
init =
    Task.succeed ()


onEffects : Platform.Router msg () -> List (WSCmd msg) -> () -> Task.Task Never ()
onEffects r cmds () =
    Task.sequence (List.map (dealWithCmd r) cmds) |> Task.andThen (\_ -> Task.succeed ())


dealWithCmd : Platform.Router msg () -> WSCmd msg -> Task.Task Never ()
dealWithCmd r cmd =
    case cmd of
        Open url onOpen onMessage onClose ->
            let
                cbMessage : WSL.WebSocket -> String -> Task.Task Never ()
                cbMessage ws payload =
                    Platform.sendToApp r (onMessage payload)

                cbClose : { code : Int, reason : String, wasClean : Bool } -> Task.Task Never ()
                cbClose details =
                    Platform.sendToApp r (onClose details.reason)
            in
            WSL.open url { onMessage = cbMessage, onClose = cbClose }
                |> Task.andThen
                    (\ws -> Platform.sendToApp r (onOpen <| Ok <| WS ws))
                |> Task.onError
                    (\err -> Platform.sendToApp r (onOpen <| Err <| toString err))

        Send ws msg onError ->
            WSL.send ws msg
                |> Task.andThen
                    (\res ->
                        case res of
                            Nothing ->
                                Task.succeed ()

                            Just badsend ->
                                Platform.sendToApp r (onError <| toString badsend)
                    )


onSelfMsg : Platform.Router msg () -> () -> () -> Task.Task Never ()
onSelfMsg router msg () =
    Task.succeed ()


{-| Open a websocket.

You pass the websocket URL and say how you want to receive messages.

    type Msg
        = ...
        | WSOpen (Result String WebSocket)
        | WSMessage String
        | WSClose String

    open "ws://example.com/"
        { onOpen = WSOpen
        , onMessage = WSMessage
        , onClose = WSClrose
        }

-}
open :
    String
    ->
        { onOpen : Result String WebSocket -> msg
        , onMessage : String -> msg
        , onClose : String -> msg
        }
    -> Cmd msg
open url handlers =
    command <| Open url handlers.onOpen handlers.onMessage handlers.onClose


{-| Send a message down a websocket.

You pass a websocket handle that you got through `open` and the payload.
In case there is an error sending the data, the error will be sent to your
app using the error handler argument.

    type Msg
        = ...
        | WSSendingError String

    send ws "{\"greeting\": \"yo!\"}" WSSendingError

-}
send : WebSocket -> String -> (String -> msg) -> Cmd msg
send (WS ws) msg onError =
    command <| Send ws msg onError
