import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "./App";
import "./App.css";

// Detect system dark mode preference and set data-theme attribute
const initTheme = () => {
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)");
  
  // Set initial theme based on system preference
  document.documentElement.dataset.theme = prefersDark.matches ? "dark" : "light";
  
  // Listen for system preference changes
  prefersDark.addEventListener("change", (e) => {
    document.documentElement.dataset.theme = e.matches ? "dark" : "light";
  });
};

initTheme();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

