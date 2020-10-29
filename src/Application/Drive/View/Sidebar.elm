module Drive.View.Sidebar exposing (view)

import Common exposing (ifThenElse)
import Common.View as Common
import Drive.Item exposing (Kind(..))
import Drive.Sidebar as Sidebar
import Drive.View.Common as Drive
import Drive.View.Details as Details
import FileSystem
import Html exposing (Html)
import Html.Attributes as A
import Html.Events as E
import Html.Events.Extra as E
import Html.Extra as Html exposing (nothing)
import Html.Lazy
import List.Extra as List
import Maybe.Extra as Maybe
import Radix exposing (..)
import Result.Extra as Result
import Routing exposing (Route(..))
import Styling as S
import Tailwind as T
import Url.Builder



-- 🖼


view : Model -> Html Msg
view model =
    case model.addOrCreate of
        Just addOrCreateModel ->
            viewSidebar
                { scrollable = True
                , expanded = addOrCreateModel.expanded
                , body = addOrCreate addOrCreateModel model
                }

        Nothing ->
            case model.sidebar of
                Just sidebar ->
                    viewSidebar
                        { scrollable = False
                        , expanded = sidebar.expanded
                        , body =
                            case sidebar.mode of
                                Sidebar.Details details ->
                                    detailsForSelection details sidebar model

                                Sidebar.EditPlaintext editor ->
                                    plaintextEditor editor sidebar model
                        }

                _ ->
                    nothing


{-| NOTE: This is positioned using `position: sticky` and using fixed px values. Kind of a hack, and should be done in a better way, but I haven't found one.
-}
viewSidebar : { scrollable : Bool, expanded : Bool, body : Html Msg } -> Html Msg
viewSidebar { scrollable, expanded, body } =
    Html.div
        [ A.class "sidebar"

        --
        , T.bg_gray_900
        , T.group
        , T.h_screen
        , T.overflow_x_hidden
        , T.rounded_md
        , T.sticky
        , T.transform
        , T.translate_x_0
        , T.w_full

        --
        , if expanded then
            T.md__w_full

          else
            T.md__w_1over2

        --
        , if scrollable then
            T.overflow_y_scroll

          else
            T.overflow_y_hidden

        -- Dark mode
        ------------
        , T.dark__bg_darkness_below
        ]
        [ body ]


plaintextEditor : Sidebar.EditorModel -> Sidebar.Model -> Model -> Html Msg
plaintextEditor editor sidebar model =
    let
        hasChanges =
            editor.text /= editor.originalText
    in
    Html.div
        [ T.flex
        , T.flex_col
        , T.items_stretch
        , T.h_full
        , T.bg_gray_700
        ]
        [ Drive.sidebarControls
            { above = False
            , canChangeSize = True
            , expanded = sidebar.expanded
            }

        --
        , Html.textarea
            [ T.w_full
            , T.h_full
            , T.bg_transparent
            , T.bg_gray_900
            , T.flex_grow
            , T.px_8
            , T.pt_8
            , T.font_mono
            , T.text_gray_100
            , T.resize_none
            , E.onInput (SidebarMsg << Sidebar.PlaintextEditorInput)
            ]
            [ Html.text editor.text ]
        , Html.div
            [ T.flex
            , T.flex_shrink_0
            , T.space_x_2
            , T.items_center
            , T.justify_end
            , T.mt_px
            , T.p_2
            , T.relative
            , T.h_12
            ]
            [ Html.div
                [ T.absolute
                , T.border_t
                , T.border_gray_300
                , T.left_0
                , T.opacity_10
                , T.top_0
                , T.right_0
                ]
                []
            , if hasChanges then
                Html.button
                    [ T.text_gray_400
                    , T.text_tiny
                    , T.tracking_wide
                    , T.px_4
                    , T.py_2
                    , T.uppercase
                    , E.onClick CloseSidebar
                    ]
                    [ Html.text "Cancel" ]

              else
                nothing
            , if hasChanges then
                Html.button
                    [ T.antialiased
                    , T.appearance_none
                    , T.bg_purple_shade
                    , T.text_tiny
                    , T.font_semibold
                    , T.leading_normal
                    , T.px_4
                    , T.py_2
                    , T.relative
                    , T.rounded
                    , T.text_white
                    , T.tracking_wider
                    , T.transition_colors
                    , T.uppercase
                    , E.onClick (SidebarMsg Sidebar.PlaintextEditorSave)
                    ]
                    [ Html.text "Save" ]

              else
                nothing
            ]
        ]



-- ADD / CREATE


addOrCreate : Sidebar.AddOrCreateModel -> Model -> Html Msg
addOrCreate addOrCreateModel model =
    Html.div
        []
        [ Drive.sidebarControls
            { above = False
            , canChangeSize = Common.isSingleFileView model
            , expanded = addOrCreateModel.expanded
            }

        --
        , addOrCreateForm addOrCreateModel model
        ]


addOrCreateForm : Sidebar.AddOrCreateModel -> Model -> Html Msg
addOrCreateForm addOrCreateModel model =
    let
        title t =
            Html.div
                [ T.font_display
                , T.font_medium
                , T.mb_3
                , T.text_gray_300
                , T.text_lg

                -- Dark mode
                ------------
                , T.dark__text_gray_400
                ]
                [ Html.text t ]
    in
    Html.div
        [ T.px_8
        , T.py_8
        ]
        [ -----------------------------------------
          -- Create
          -----------------------------------------
          title "Create directory"

        --
        , Html.form
            [ E.onSubmit CreateDirectory

            --
            , T.flex
            , T.max_w_md
            ]
            [ S.textField
                [ A.placeholder "Magic Box"
                , E.onInput GotCreateDirectoryInput
                , T.w_0
                , A.value addOrCreateModel.input
                ]
                []

            --
            , S.button
                [ T.bg_purple
                , T.ml_3
                , T.px_6
                , T.text_tiny
                ]
                [ if model.fileSystemStatus == FileSystem.Operation FileSystem.CreatingDirectory then
                    Common.loadingAnimationWithAttributes
                        [ T.text_purple_tint ]
                        { size = S.iconSize }

                  else
                    Html.text "Create"
                ]
            ]

        -----------------------------------------
        -- Add
        -----------------------------------------
        , Html.div
            [ T.mt_12 ]
            [ title "Add files" ]

        --
        , Html.div
            [ T.relative
            , T.text_center
            ]
            [ Html.node
                "fs-content-uploader"
                [ E.on "changeBlobs" Common.blobUrlsDecoder

                --
                , A.style "min-height" "108px"
                , A.style "padding-top" (ifThenElse addOrCreateModel.expanded "19%" "22.5%")

                --
                , T.border_2
                , T.border_dashed
                , T.border_gray_500
                , T.block
                , T.cursor_pointer
                , T.h_0
                , T.overflow_hidden
                , T.rounded

                -- Dark mode
                ------------
                , T.dark__border_darkness_above
                ]
                []

            --
            , Html.div
                [ T.absolute
                , T.flex
                , T.font_light
                , T.italic
                , T.justify_center
                , T.leading_tight
                , T.left_1over2
                , T.neg_translate_x_1over2
                , T.neg_translate_y_1over2
                , T.pointer_events_none
                , T.px_4
                , T.text_gray_400
                , T.top_1over2
                , T.transform
                , T.truncate
                , T.w_full

                -- Dark mode
                ------------
                , T.dark__text_gray_300
                ]
                [ Html.text "Click to choose, or drop some files"
                ]
            ]
        ]



-- DETAILS


detailsForSelection : { showPreviewOverlay : Bool } -> Sidebar.Model -> Model -> Html Msg
detailsForSelection { showPreviewOverlay } sidebar model =
    Html.div
        [ T.flex
        , T.flex_col
        , T.h_full
        , T.items_center
        , T.justify_center
        , T.px_4
        , T.py_6
        ]
        [ model.selectedPath
            |> Maybe.andThen
                (\path ->
                    model.directoryList
                        |> Result.map .items
                        |> Result.withDefault []
                        |> List.find (.path >> (==) path)
                )
            |> Maybe.map
                (Html.Lazy.lazy6
                    Details.view
                    (Result.unwrap True (.floor >> (==) 1) model.directoryList)
                    (Common.isSingleFileView model)
                    model.currentTime
                    sidebar.expanded
                    showPreviewOverlay
                )
            |> Maybe.withDefault
                nothing
        ]
