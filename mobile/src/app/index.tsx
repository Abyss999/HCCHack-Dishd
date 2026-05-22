import { Redirect } from "expo-router";
import { useAuth } from "@/hooks/useAuth";
import { View, ActivityIndicator } from "react-native";

export default function Index() {
  const { tokens, isLoading } = useAuth();

  if (isLoading) {
    return (
      <View style={{ flex: 1, backgroundColor: "#1a1a1a", justifyContent: "center", alignItems: "center" }}>
        <ActivityIndicator color="#d97757" />
      </View>
    );
  }

  if (tokens) {
    return <Redirect href="/(tabs)" />;
  }

  return <Redirect href="/auth/login" />;
}
