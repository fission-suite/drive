module State exposing (init, subscriptions, update)

import Authentication.Essentials as Authentication
import Browser.Events as Browser
import Browser.Navigation as Navigation
import Common exposing (ifThenElse)
import Common.State as Common
import Debouncer.Messages as Debouncer
import Debouncing
import Drive.Sidebar
import Drive.State as Drive
import FileSystem
import FileSystem.State as FileSystem
import Keyboard
import Maybe.Extra as Maybe
import Notifications
import Other.State as Other
import Ports
import Radix exposing (..)
import Return
import Routing
import Task
import Time
import Toasty
import Url exposing (Url)



-- 🌱


init : Flags -> Url -> Navigation.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        route =
            Routing.routeFromUrl flags.authenticated url

        maybeTreeRoot =
            Routing.treeRoot route

        fileSystemStatus =
            if Maybe.isJust maybeTreeRoot then
                FileSystem.InitialListing

            else
                FileSystem.NotNeeded

        needsRedirect =
            (Routing.isAuthenticatedTree flags.authenticated route == False)
                && (List.head (Routing.treePathSegments route) == Just "public")
    in
    ( -----------------------------------------
      -- Model
      -----------------------------------------
      { authenticated = flags.authenticated
      , currentTime = Time.millisToPosix flags.currentTime
      , contextMenu = Nothing
      , directoryList = Ok { floor = 1, items = [] }
      , dragndropMode = False
      , fileSystemCid = Nothing
      , fileSystemStatus = fileSystemStatus
      , helpfulNote = Nothing
      , isFocused = False
      , modal = Nothing
      , navKey = navKey
      , route = route
      , pressedKeys = []
      , viewportSize = flags.viewportSize
      , selectedPath = Nothing
      , showLoadingOverlay = False
      , toasties = Toasty.initialState
      , url = url
      , usersDomain = flags.usersDomain

      -- Debouncers
      -------------
      , loadingDebouncer = Debouncing.loading.debouncer
      , notificationsDebouncer = Debouncing.notifications.debouncer

      -- Sidebar
      ----------
      , createDirectoryInput = ""
      , expandSidebar = False
      , showPreviewOverlay = False
      , sidebarMode = Drive.Sidebar.defaultMode
      }
      -----------------------------------------
      -- Command
      -----------------------------------------
    , Cmd.batch
        [ Task.perform SetCurrentTime Time.now

        -- FileSystem
        -------------
        , if needsRedirect then
            route
                |> Routing.treePathSegments
                |> List.drop 1
                |> Routing.replaceTreePathSegments route
                |> Routing.adjustUrl url
                |> Url.toString
                |> Navigation.pushUrl navKey

          else if Routing.isAuthenticatedTree flags.authenticated route then
            -- List entire file system for the authenticated user
            Ports.fsListDirectory
                { pathSegments = Routing.treePathSegments route }

          else if Maybe.isJust maybeTreeRoot then
            -- List a public filesystem
            Ports.fsListPublicDirectory
                { pathSegments =
                    Routing.treePathSegments route
                , root =
                    Common.filesDomainFromTreeRoot
                        { usersDomain = flags.usersDomain }
                        maybeTreeRoot
                }

          else
            Cmd.none
        ]
    )



-- 📣


update : Msg -> Model -> ( Model, Cmd Msg )
update msg =
    case msg of
        Bypass ->
            Return.singleton

        -----------------------------------------
        -- Debouncers
        -----------------------------------------
        LoadingDebouncerMsg a ->
            Debouncer.update update Debouncing.loading.updateConfig a

        NotificationsDebouncerMsg a ->
            Debouncer.update update Debouncing.notifications.updateConfig a

        -----------------------------------------
        -- Drive
        -----------------------------------------
        ActivateSidebarMode a ->
            Drive.activateSidebarMode a

        AddFiles a ->
            Drive.addFiles a

        CloseSidebar ->
            Drive.closeSidebar

        CopyPublicUrl a ->
            Drive.copyPublicUrl a

        CopyToClipboard a ->
            Drive.copyToClipboard a

        CreateDirectory ->
            Drive.createDirectory

        DigDeeper a ->
            Drive.digDeeper a

        DownloadItem a ->
            Drive.downloadItem a

        GotCreateDirectoryInput a ->
            Drive.gotCreateDirectoryInput a

        GoUp a ->
            Drive.goUp a

        RemoveItem a ->
            Drive.removeItem a

        RenameItem a ->
            Drive.renameItem a

        Select a ->
            Drive.select a

        ShowPreviewOverlay ->
            Drive.showPreviewOverlay

        ShowRenameItemModal a ->
            Drive.showRenameItemModal a

        ToggleExpandedSidebar ->
            Drive.toggleExpandedSidebar

        ToggleSidebarMode a ->
            Drive.toggleSidebarMode a

        -----------------------------------------
        -- File System
        -----------------------------------------
        GotFsDirectoryList a ->
            FileSystem.gotDirectoryList a

        GotItemUtf8 a ->
            FileSystem.gotItemUtf8 a

        GotFsError a ->
            FileSystem.gotError a

        -----------------------------------------
        -- 🌏 Common
        -----------------------------------------
        GoToRoute a ->
            Common.goToRoute a

        HideHelpfulNote ->
            Common.hideHelpfulNote

        HideModal ->
            Common.hideModal

        RemoveContextMenu ->
            Common.removeContextMenu

        RemoveHelpfulNote ->
            Common.removeHelpfulNote

        Reset a ->
            Common.reset a

        SetModalState a b ->
            Common.setModalState a b

        ShowContextMenu a b ->
            Common.showContextMenu a b

        ShowContextMenuWithCoordinates a b ->
            Common.showContextMenuWithCoordinates a b

        ShowHelpfulNote a ->
            Common.showHelpfulNote a

        -----------------------------------------
        -- 🐚 Other
        -----------------------------------------
        Blurred ->
            Other.blurred

        Focused ->
            Other.focused

        HideWelcomeMessage ->
            Other.hideWelcomeMessage

        KeyboardInteraction a ->
            Other.keyboardInteraction a

        LinkClicked a ->
            Other.linkClicked a

        RedirectToLobby ->
            Other.redirectToLobby

        ScreenSizeChanged a b ->
            Other.screenSizeChanged a b

        SetCurrentTime a ->
            Other.setCurrentTime a

        ToastyMsg a ->
            Toasty.update Notifications.config ToastyMsg a

        ToggleLoadingOverlay a ->
            Other.toggleLoadingOverlay a

        UrlChanged a ->
            Other.urlChanged a



-- 📰


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.fsGotDirectoryList GotFsDirectoryList
        , Ports.fsGotItemUtf8 GotItemUtf8
        , Ports.fsGotError GotFsError

        -- Keep track of which keyboard keys are pressed
        , Sub.map KeyboardInteraction Keyboard.subscriptions

        -- Monitor screen size
        , Browser.onResize ScreenSizeChanged

        -- Check every 30 seconds what the current time is
        , Time.every (30 * 1000) SetCurrentTime
        ]
