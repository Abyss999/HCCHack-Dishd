import React, { useState } from "react";
import {
  View,
  Text,
  TextInput,
  Pressable,
  ScrollView,
  SafeAreaView,
} from "react-native";
import { useRouter } from "expo-router";
import * as Haptics from "expo-haptics";
import Toast from "react-native-toast-message";
import { useAuth } from "@/hooks/useAuth";
import { useColors } from "@/hooks/useColors";

export default function LoginScreen() {
  const router = useRouter();
  const { login } = useAuth();
  const colors = useColors();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    if (!email.trim() || !password) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      Toast.show({ type: "error", text1: "Missing fields", text2: "Please fill in all fields" });
      return;
    }

    try {
      setLoading(true);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      await login(email.trim().toLowerCase(), password);
    } catch {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({ type: "error", text1: "Login failed", text2: "Invalid email or password" });
    } finally {
      setLoading(false);
    }
  };

  const inputStyle = {
    color: colors.text,
    fontFamily: "IBM Plex Mono",
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderRadius: 10,
    backgroundColor: colors.inputBg,
    borderWidth: 1,
    borderColor: colors.inputBorder,
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView style={{ flex: 1, paddingHorizontal: 16 }}>
        <View style={{ flex: 1, justifyContent: "center", paddingVertical: 48 }}>
          {/* Header */}
          <View style={{ marginBottom: 48 }}>
            <Text className="font-dm-sans text-display-1 text-primary mb-2">
              DishMatch
            </Text>
            <Text style={{ color: colors.textSecondary }} className="text-body">
              Find your perfect meal together
            </Text>
          </View>

          {/* Form */}
          <View style={{ gap: 16, marginBottom: 24 }}>
            <View>
              <Text style={{ color: colors.textSecondary }} className="text-body-sm mb-2">
                Email
              </Text>
              <TextInput
                placeholder="you@example.com"
                placeholderTextColor={colors.placeholderText}
                value={email}
                onChangeText={setEmail}
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="email"
                textContentType="emailAddress"
                editable={!loading}
                style={inputStyle}
              />
            </View>

            <View>
              <Text style={{ color: colors.textSecondary }} className="text-body-sm mb-2">
                Password
              </Text>
              <TextInput
                placeholder="••••••••"
                placeholderTextColor={colors.placeholderText}
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                autoComplete="current-password"
                textContentType="password"
                editable={!loading}
                style={inputStyle}
              />
            </View>
          </View>

          {/* Login button */}
          <Pressable
            onPress={handleLogin}
            disabled={loading}
            style={{
              backgroundColor: colors.primary,
              paddingVertical: 14,
              borderRadius: 10,
              alignItems: "center",
              justifyContent: "center",
              marginBottom: 16,
              opacity: loading ? 0.5 : 1,
              shadowColor: colors.primary,
              shadowOffset: { width: 0, height: 4 },
              shadowOpacity: 0.3,
              shadowRadius: 8,
              elevation: 4,
            }}
          >
            <Text className="text-white font-roboto font-medium text-body">
              {loading ? "Logging in..." : "Log in"}
            </Text>
          </Pressable>

          {/* Sign up link */}
          <View style={{ flexDirection: "row", justifyContent: "center", gap: 4 }}>
            <Text style={{ color: colors.text }} className="text-body">
              Don't have an account?
            </Text>
            <Pressable onPress={() => router.push("/auth/signup")}>
              <Text className="text-body font-medium text-primary">
                Sign up
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
