{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name =
    "siren"
, dependencies =
    [ "effect"
    , "console"
    , "halogen"
    , "halogen-css"
    , "psci-support"
    , "debug"
    , "web-socket"
    ]
, packages =
    ./packages.dhall
, sources =
    [ "src/*.purs", "src/**/*.purs", "test/**/*.purs" ]
}
