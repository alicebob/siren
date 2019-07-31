module Main where

import Prelude

import Control.Monad.State (get, put)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Scaffolding.DynamicRenderer.StateAndEval (HandleSimpleAction, StateAndActionRenderer, runStateAndActionComponent)


type State = Boolean

data Action = Toggle

toggleButton :: StateAndActionRenderer State Action
toggleButton isOn =
  let toggleLabel = if isOn then "ON" else "OFF"
  in
    HH.button
      [ HE.onClick \_ -> Just Toggle ]
      [ HH.text $ "The button is " <> toggleLabel ]

handleAction :: HandleSimpleAction State Action
handleAction = case _ of
  Toggle -> do
    oldState <- get
    let newState = not oldState
    put newState


main :: Effect Unit
main = do
  runStateAndActionComponent
    { initialState: false
    , render: toggleButton
    , handleAction: handleAction
    }
