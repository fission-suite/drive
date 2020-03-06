module Explore.State exposing (..)

import Browser.Navigation as Navigation
import Ipfs
import Ipfs.State
import Maybe.Extra as Maybe
import Ports
import Return exposing (return)
import Routing
import Types exposing (..)
import Url



-- 📣


explore : Manager
explore model =
    case Maybe.unwrap "" String.trim model.exploreInput of
        "" ->
            Return.singleton model

        input ->
            return
                { model | ipfs = Ipfs.InitialListing, roots = Nothing }
                (Ports.ipfsResolveAddress input)


gotInput : String -> Manager
gotInput input model =
    Return.singleton
        { model
            | ipfs = Ipfs.Ready
            , exploreInput = Just input
            , roots = Nothing
        }


reset : Manager
reset model =
    return
        { model
            | directoryList = Ok []
            , exploreInput = Just ""
            , roots = Nothing
            , selectedCid = Nothing
        }
        (Cmd.batch
            [ Ports.removeStoredRoots ()

            --
            , Routing.Blank
                |> Routing.adjustUrl model.url
                |> Url.toString
                |> Navigation.pushUrl model.navKey
            ]
        )
