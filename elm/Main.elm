import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Http
import WebSocket
import Json.Decode as Decode


main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Model = 
    { status : Status
    }

init : (Model, Cmd Msg)
init =
  ( Model {state="", songid="", time="", elapsed=""}
  , Cmd.none
  )

type Msg
  = PressPlay
  | PressPause
  | PressStop
  | PressRes (Result Http.Error String)
  | NewWSMessage String


type alias Status =
    { state : String -- "play", ...
    , songid : String
    , time : String
    , elapsed : String
}


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    PressPlay ->
      (model, doAction "play")

    PressPause ->
      (model, doAction "pause")

    PressStop ->
      (model, doAction "stop")

    PressRes (Ok newUrl) ->
      (model , Cmd.none)

    PressRes (Err _) ->
      (model, Cmd.none) -- TODO: log or something

    NewWSMessage m ->
      case Decode.decodeString statusDecoder m of
        Err _ -> (model, Cmd.none) -- TODO: log
        Ok s ->
            ({ model | status = s }, Cmd.none)

view : Model -> Html Msg
view model =
  div []
    [ button [ onClick PressPlay ] [ text "⏯" ]
    , button [ onClick PressPause ] [ text "⏸" ]
    , button [ onClick PressStop ] [ text "⏹" ]
    , text " - "
    , text <| "Currently: " ++ model.status.state ++ " "
    , text <| "Song: " ++ model.status.songid ++ " "
    , text <| "Time: " ++ model.status.elapsed ++ "/" ++ model.status.time
    ]

subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen "ws://localhost:6601/mpd/ws" NewWSMessage


doAction : String -> Cmd Msg
doAction a =
  let
    url =
      "/mpd/" ++ a
  in
    Http.send PressRes (Http.getString url)


statusDecoder : Decode.Decoder Status
statusDecoder =
    Decode.map4
      Status
      (Decode.field "state" Decode.string)
      (Decode.field "songid" Decode.string)
      (Decode.field "time" Decode.string)
      (Decode.field "elapsed" Decode.string)

