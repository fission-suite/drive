module Ipfs.State exposing (..)

import Browser.Dom as Dom
import Debouncing
import Ipfs
import Item
import Json.Decode as Json
import Ports
import Return exposing (return)
import Routing
import Task
import Types exposing (..)



-- DIRECTORY LIST


getDirectoryListCmd : Model -> Cmd Msg
getDirectoryListCmd model =
    let
        pathSegments =
            Routing.drivePathSegments model.page

        cid =
            pathSegments
                |> (case model.roots of
                        Just { resolved } ->
                            (::) resolved

                        Nothing ->
                            identity
                   )
                |> String.join "/"
    in
    Ports.ipfsListDirectory
        { cid = cid
        , pathSegments = pathSegments
        }


gotDirectoryList : Json.Value -> Manager
gotDirectoryList encodedFeedback model =
    let
        pathSegments =
            encodedFeedback
                |> Json.decodeValue
                    (Json.field "pathSegments" <| Json.list Json.string)
                |> Result.withDefault
                    []

        encodedDirList =
            encodedFeedback
                |> Json.decodeValue
                    (Json.field "results" Json.value)
                |> Result.withDefault
                    encodedFeedback
    in
    case model.ipfs of
        Ipfs.InitialListing ->
            gotDirectoryList_ encodedDirList model

        Ipfs.AdditionalListing ->
            if Routing.drivePathSegments model.page == pathSegments then
                gotDirectoryList_ encodedDirList model

            else
                Return.singleton model

        _ ->
            Return.singleton model


gotDirectoryList_ : Json.Value -> Manager
gotDirectoryList_ encodedDirList model =
    encodedDirList
        |> Json.decodeValue (Json.list Ipfs.listItemDecoder)
        |> Result.map (List.map Item.fromIpfs)
        |> Result.mapError Json.errorToString
        |> (\result ->
                { model
                    | directoryList = Result.map (List.sortWith Item.sortingFunction) result
                    , ipfs = Ipfs.Ready
                    , showLoadingOverlay = False
                }
           )
        |> Return.singleton
        |> Return.andThen Debouncing.cancelLoading
        |> Return.command
            (Task.attempt
                (always Bypass)
                (Dom.setViewport 0 0)
            )



-- ERRORS


gotError : String -> Manager
gotError error model =
    Return.singleton
        { model
            | exploreInput = Maybe.map .unresolved model.roots
            , ipfs = Ipfs.Error error
        }



-- SETUP


gotResolvedAddress : Roots -> Manager
gotResolvedAddress roots model =
    { model | roots = Just roots }
        |> Return.singleton
        |> Return.effect_ getDirectoryListCmd
        |> Return.command (Ports.storeRoots roots)


setupCompleted : Manager
setupCompleted model =
    case model.roots of
        Just _ ->
            return { model | ipfs = Ipfs.InitialListing } (getDirectoryListCmd model)

        Nothing ->
            Return.singleton { model | ipfs = Ipfs.Ready }
