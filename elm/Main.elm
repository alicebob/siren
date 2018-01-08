import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Http

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

type alias Model = {}

init : (Model, Cmd Msg)
init =
  ( Model 
  , Cmd.none
  )

type Msg
  = PressPlay
  | PressPause
  | PressStop
  | PressRes (Result Http.Error String)


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
      (Model , Cmd.none)

    PressRes (Err _) ->
      (model, Cmd.none) -- TODO: log or something

view : Model -> Html Msg
view model =
  div []
    [ button [ onClick PressPlay ] [ text "⏯" ]
    , button [ onClick PressPause ] [ text "⏸" ]
    , button [ onClick PressStop ] [ text "⏹" ]
    ]

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

doAction : String -> Cmd Msg
doAction a =
  let
    url =
      "/mpd/" ++ a
  in
    Http.send PressRes (Http.getString url)

