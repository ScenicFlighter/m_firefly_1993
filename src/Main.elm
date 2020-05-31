-- Main.elm
module Main exposing (main)

import Browser

import File exposing (File)
import File.Select as Select

import Html exposing (Html, button, div, text, nav, a, ul, li, span, main_, label, input, img, p)
import Html.Attributes exposing (class, href, target, type_, src)
import Html.Events exposing (onClick)

import Http
import Json.Encode as JsonEncode

import Loading
  exposing
      ( LoaderType(..)
      , defaultConfig
      , render
      )

import Task

import Debug

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

init : Flags -> ( Model, Cmd msg )
init flags =
    (
      {
        analyzeResult = "", image = Nothing, error = Nothing, loading = "", apiEndpoint = flags.apiEndpoint
      },
      Cmd.none
    )
type alias Flags =
  { apiEndpoint : String }

-- MODEL
type alias Model =
  {
    image: Maybe String,
    error: Maybe LoadErr,
    analyzeResult: String,
    apiEndpoint: String,
    loading: String
  }

-- UPDATE
type Msg
    = ImageRequested
    | ImageSelected File
    | ImageLoaded (Result LoadErr String)
    | GetAnalyze
    | GotAnalyze (Result Http.Error String)

type LoadErr
    = ErrToUrlFailed
    | ErrInvalidFile


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetAnalyze ->
            ( {model | loading = "loading", analyzeResult = ""}
            , getAnalyze model
            )

        GotAnalyze result ->
            case result of
                Ok res ->
                    ( { model | analyzeResult = res, loading = "" }, Cmd.none )

                Err _ ->
                    ( {model | loading = ""}, Cmd.none )

        ImageRequested ->
            ( model
            , Select.file expectedTypes ImageSelected
            )

        ImageSelected file ->
            ( model
            , Task.attempt ImageLoaded
                (guardType file
                    |> Task.andThen File.toUrl
                )
            )

        ImageLoaded result ->
            case result of
                Ok content ->
                    ( { model
                        | image = Just content
                        , error = Nothing
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | image = Nothing
                        , error = Just error
                      }
                    , Cmd.none
                    )


expectedTypes : List String
expectedTypes =
    [ "image/png", "image/jpg", "image/jpeg", "image/gif" ]

guardType : File -> Task.Task LoadErr File
guardType file =
    if List.any ((==) <| File.mime file) expectedTypes then
        Task.succeed file
    else
        Task.fail ErrInvalidFile

getAnalyze : Model -> Cmd Msg
getAnalyze model =
    Http.request
        { method = "POST"
        , headers =
            [
              Http.header "Accept" "application/json"
            , Http.header "Content-Type" "application/json"
            ]
        , url = model.apiEndpoint
        , expect = Http.expectString GotAnalyze
        , body = Http.jsonBody <| JsonEncode.object [("image", JsonEncode.string (
          case model.image of
            Nothing -> ""
            Just content -> content
        ))]
        -- , body = Http.emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }

-- VIEW
view : Model -> Html Msg
view model =
  main_ []
    [
      nav [class "app_nav"]
        [
          div [class "nav_title"]
          [
            a [ class "hover:text-white hover:no-underline"]
            [span [ class "hover:text-white hover:no-underline" ] [text "[M] firefly"]]
          ],
          div [class "w-full flex-grow lg:flex lg:items-center lg:w-auto hidden lg:block pt-6 lg:pt-0"]
          [
            ul [class "list-reset lg:flex justify-end flex-1 items-center"] [
              li [class "mr-3"] [a[
                  class "nav_link hover:border-transparent hover:text-teal-500 hover:bg-white mt-4 lg:mt-0",
                  href "https://github.com/ScenicFlighter/m_firefly_1993",
                  target "_blank"
                ] 
                [text "Github"]]
            ]
          ]
        ],
      div [class "container shadow-sm mx-auto bg-white mt-24 md:mt-18"]
        [
          div [class "bd_alert lg:px-4"]
          [
            div [class "lg:rounded-full flex lg:inline-flex"] [
              span [] [text "If you put a picture of a person's face, it will be determined whether the person is `Kasumi Arimura.`"]
            ]
          ]
        ],
      div [class "flex w-full mt-10 mb-10 items-center justify-center bg-grey-lighter"]
      [
        case model.image of
          Nothing -> img [class "object-contain sm:object-cover md:object-fill lg:object-none xl:object-scale-down", src "https://placehold.jp/99ccff/003366/300x300.png?text=Face%20Image..."][]
          Just content -> img[class "object-contain sm:object-cover md:object-fill lg:object-none xl:object-scale-down", src content][]
      ],
      div [class "flex w-full mt-10 mb-10 items-center justify-center bg-grey-lighter"]
      [
        label [
          class "image_select text-blue border-blue hover:bg-blue hover:text-gray-700"
        ]
        [
          span [class "text-base leading-normal"][text "Select Picture..."],
          input [class "hidden", onClick ImageRequested ] [],
          div [] [text <|
            case model.error of
              Nothing -> ""
              Just ErrInvalidFile -> "Invalid"
              Just ErrToUrlFailed -> "Failed"
          ]
        ]
      ],
      div [class "container mx-auto"]
      [
        case model.analyzeResult of
          "" -> div [] []
          "unmatch" -> div [class "message"] [p [class "font-bold text-center"] [text "wrong..."]]
          "match" -> div [class "message"] [p [class "font-bold text-center"] [text "She is `Kasumi Arimura`!"]]
          _ -> div [] []
      ],
      div [class "container mx-auto flex items-center justify-center"]
      [
        case model.loading of
          "" -> div [] []
          "loading" -> div [ ] [ Loading.render
                          Bars -- LoaderType
                          { defaultConfig | color = "#484848" } -- Config
                          Loading.On -- LoadingState
                      ]
          _ -> div [] []
      ],
      div [class "container mx-auto"]
      [
        case model.image of
          Nothing -> div [] []
          Just content ->
              case model.loading of
              "" -> 
                div [class "bd_alert px-4"]
                  [
                    div [class "rounded-full flex inline-flex"] [
                      button [class "btn-primary w-full", onClick GetAnalyze] [text "Analyze!"]
                    ]
                  ]
              "loading" ->
                  div [class "bd_alert px-4"]
                  [
                    div [class "rounded-full flex inline-flex"] [
                      button [class "btn-disable w-full"] [text "Analyze!"]
                    ]
                  ]
              _ -> div [] []
      ]
    ]


-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none