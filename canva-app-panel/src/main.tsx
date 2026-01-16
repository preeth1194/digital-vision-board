import React from "react";
import ReactDOM from "react-dom/client";
import { AppUiProvider } from "@canva/app-ui-kit";
import "@canva/app-ui-kit/styles.css";
import { App } from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AppUiProvider>
      <App />
    </AppUiProvider>
  </React.StrictMode>,
);

