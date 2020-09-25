module FileSystem.State exposing (..)

import Browser.Dom as Dom
import Common
import Common.State as Common
import Debouncing
import Drive.Item
import FileSystem
import Json.Decode as Json
import List.Extra as List
import Maybe.Extra as Maybe
import Ports
import Radix exposing (..)
import Return exposing (return)
import Return.Extra as Return
import Routing
import Task



-- 🐚


gotDirectoryList : Json.Value -> Manager
gotDirectoryList json model =
    let
        pathSegments =
            json
                |> Json.decodeValue
                    (Json.field "pathSegments" <| Json.list Json.string)
                |> Result.withDefault
                    []

        encodedDirList =
            json
                |> Json.decodeValue
                    (Json.field "results" Json.value)
                |> Result.withDefault
                    json
    in
    encodedDirList
        |> Json.decodeValue (Json.list FileSystem.itemDecoder)
        |> Result.map (List.map Drive.Item.fromFileSystem)
        |> Result.mapError Json.errorToString
        |> (\result ->
                let
                    floor =
                        List.length pathSegments + 1

                    listResult =
                        Result.map
                            ({ isGroundFloor = floor == 1 }
                                |> Drive.Item.sortingFunction
                                |> List.sortWith
                            )
                            result

                    lastRouteSegment =
                        List.last (Routing.treePathSegments model.route)

                    selectedPath =
                        case listResult of
                            Ok [ singleItem ] ->
                                if Just singleItem.name == lastRouteSegment then
                                    Just singleItem.path

                                else
                                    Nothing

                            _ ->
                                Nothing
                in
                { model
                    | directoryList =
                        Result.map
                            (\items -> { floor = floor, items = items })
                            listResult

                    --
                    , expandSidebar = Maybe.isJust selectedPath
                    , fileSystemStatus = FileSystem.Ready
                    , selectedPath = selectedPath
                    , showLoadingOverlay = False
                }
           )
        |> Common.potentiallyRenderMedia
        |> Return.andThen Debouncing.cancelLoading
        |> Return.command
            (Task.attempt
                (always Bypass)
                (Dom.setViewport 0 0)
            )


gotError : String -> Manager
gotError error model =
    Return.singleton { model | fileSystemStatus = FileSystem.Error error }
