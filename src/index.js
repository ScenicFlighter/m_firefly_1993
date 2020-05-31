/**
 * Application Root Index
 */
import {Elm} from './Main.elm';

import "./styles/app.scss";

Elm.Main.init({
    node: document.getElementById("apex"),
    flags: {apiEndpoint: process.env.API_ENDPOINT},
});
