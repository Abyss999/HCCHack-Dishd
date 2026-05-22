import "../global.css";

import { Stack } from "expo-router";
import { StatusBar } from "react-native";
import Toast, { BaseToast, ErrorToast } from "react-native-toast-message";
import { useAuth } from "@/hooks/useAuth";
import { ThemeProvider, useTheme } from "@/context/ThemeContext";
import { useColors } from "@/hooks/useColors";

function RootLayoutInner() {
  const { isLoading } = useAuth();
  const { resolvedScheme } = useTheme();
  const colors = useColors();

  const toastConfig = {
    success: (props: any) => (
      <BaseToast
        {...props}
        style={{
          borderLeftColor: "#d97757",
          backgroundColor: colors.surface,
          borderRadius: 12,
          height: "auto",
          paddingVertical: 10,
        }}
        contentContainerStyle={{ paddingHorizontal: 14 }}
        text1Style={{ color: colors.text, fontFamily: "Roboto", fontSize: 14, fontWeight: "600" }}
        text2Style={{ color: colors.textSecondary, fontFamily: "Roboto", fontSize: 12 }}
      />
    ),
    error: (props: any) => (
      <ErrorToast
        {...props}
        style={{
          borderLeftColor: "#ef5350",
          backgroundColor: colors.surface,
          borderRadius: 12,
          height: "auto",
          paddingVertical: 10,
        }}
        contentContainerStyle={{ paddingHorizontal: 14 }}
        text1Style={{ color: colors.text, fontFamily: "Roboto", fontSize: 14, fontWeight: "600" }}
        text2Style={{ color: colors.textSecondary, fontFamily: "Roboto", fontSize: 12 }}
      />
    ),
  };

  return (
    <>
      <StatusBar
        barStyle={resolvedScheme === "dark" ? "light-content" : "dark-content"}
        backgroundColor={resolvedScheme === "dark" ? "#1a1a1a" : "#faf9f7"}
      />
      {isLoading ? (
        <Stack screenOptions={{ headerShown: false }} />
      ) : (
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="auth" options={{ animation: "none" }} />
          <Stack.Screen name="(tabs)" options={{ animation: "none" }} />
          <Stack.Screen name="session" />
        </Stack>
      )}
      <Toast config={toastConfig} topOffset={60} />
    </>
  );
}

export default function RootLayout() {
  return (
    <ThemeProvider>
      <RootLayoutInner />
    </ThemeProvider>
  );
}
