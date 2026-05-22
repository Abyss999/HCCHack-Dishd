/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  darkMode: "media",
  theme: {
    extend: {
      colors: {
        // Primary (Warm Oranges/Browns) — same on both modes
        primary: {
          DEFAULT: "#d97757",
          light: "#f5a76d",
          dark: "#c7622a",
          accent: "#e8a885",
        },
        // Neutrals — Light mode defaults
        neutral: {
          bg: "#faf9f7",
          surface: "#f2efeb",
          "surface-light": "#e8e3dc",
          text: "#1c1917",
          "text-secondary": "#78716c",
          "text-tertiary": "#a8a29e",
          border: "#d6d0c8",
        },
        // Neutrals — Dark mode (used with dark: prefix)
        night: {
          bg: "#0a0a0a",
          surface: "#1a1a1a",
          "surface-light": "#262626",
          text: "#ffffff",
          "text-secondary": "#b3b3b3",
          "text-tertiary": "#808080",
          border: "#404040",
        },
        // Semantic
        success: "#4caf50",
        destructive: "#ef5350",
        warning: "#ffa726",
        info: "#29b6f6",
      },
      fontFamily: {
        "dm-sans": ["DM Sans", "sans-serif"],
        roboto: ["Roboto", "sans-serif"],
        mono: ["IBM Plex Mono", "monospace"],
      },
      fontSize: {
        "display-1": ["40px", { lineHeight: "48px" }],
        "display-2": ["32px", { lineHeight: "40px" }],
        "h1": ["26px", { lineHeight: "32px" }],
        "h2": ["20px", { lineHeight: "28px" }],
        "h3": ["18px", { lineHeight: "26px" }],
        "body": ["15px", { lineHeight: "24px" }],
        "body-sm": ["14px", { lineHeight: "20px" }],
        "caption": ["12px", { lineHeight: "16px" }],
        "caption-sm": ["11px", { lineHeight: "14px" }],
      },
      spacing: {
        "1": "4px",
        "2": "8px",
        "3": "12px",
        "4": "16px",
        "6": "24px",
        "8": "32px",
        "12": "48px",
        "15": "60px",
      },
      borderRadius: {
        "sm": "12px",
        "md": "16px",
        "lg": "24px",
      },
    },
  },
  plugins: [],
};
