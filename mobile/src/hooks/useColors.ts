import { useTheme } from "@/context/ThemeContext";

const LIGHT = {
  bg: "#faf9f7",
  surface: "#f2efeb",
  surfaceLight: "#e8e3dc",
  text: "#1c1917",
  textSecondary: "#78716c",
  textTertiary: "#a8a29e",
  border: "#d6d0c8",
  primary: "#d97757",
  primaryLight: "#f5a76d",
  placeholderText: "#a8a29e",
  inputBg: "#f2efeb",
  inputBorder: "rgba(217, 119, 87, 0.3)",
  cardBg: "#f2efeb",
  cardBorder: "rgba(217, 119, 87, 0.15)",
  chipBg: "rgba(217, 119, 87, 0.08)",
  chipBorder: "rgba(217, 119, 87, 0.2)",
  progressBg: "rgba(217, 119, 87, 0.15)",
  rankBadgeFallback: "#e8e3dc",
  rankBadgeFallbackText: "#1c1917",
};

const DARK = {
  bg: "#0a0a0a",
  surface: "#1a1a1a",
  surfaceLight: "#262626",
  text: "#ffffff",
  textSecondary: "#b3b3b3",
  textTertiary: "#808080",
  border: "#404040",
  primary: "#d97757",
  primaryLight: "#f5a76d",
  placeholderText: "rgba(255, 255, 255, 0.4)",
  inputBg: "rgba(26, 26, 26, 0.8)",
  inputBorder: "rgba(217, 119, 87, 0.25)",
  cardBg: "#1a1a1a",
  cardBorder: "rgba(217, 119, 87, 0.15)",
  chipBg: "rgba(217, 119, 87, 0.1)",
  chipBorder: "rgba(217, 119, 87, 0.2)",
  progressBg: "rgba(217, 119, 87, 0.2)",
  rankBadgeFallback: "#3d3d3d",
  rankBadgeFallbackText: "#ffffff",
};

export type Colors = typeof DARK;

export function useColors(): Colors {
  const { resolvedScheme } = useTheme();
  return resolvedScheme === "dark" ? DARK : LIGHT;
}
