import React, { useState, useEffect } from "react";
import {
  View,
  Text,
  ScrollView,
  SafeAreaView,
  Pressable,
  Alert,
} from "react-native";
import { useAuth } from "@/hooks/useAuth";
import { useColors } from "@/hooks/useColors";
import { useTheme, ThemeMode } from "@/context/ThemeContext";
import { UserPreferences } from "@/types";

const DISTANCE_OPTIONS_MI = [
  { mi: 1, km: 2 },
  { mi: 5, km: 8 },
  { mi: 10, km: 16 },
  { mi: 25, km: 40 },
];

const milesFromKm = (km: number) => {
  const match = DISTANCE_OPTIONS_MI.find((o) => o.km === km);
  return match ? match.mi : Math.round(km * 0.621);
};

export default function ProfileScreen() {
  const { user, tokens, logout } = useAuth();
  const colors = useColors();
  const { themeMode, setThemeMode } = useTheme();
  const [preferences, setPreferences] = useState<UserPreferences | null>(null);
  const [loading, setLoading] = useState(false);

  const API_BASE = process.env.EXPO_PUBLIC_API_URL || "http://localhost:8000";

  useEffect(() => {
    if (user?.preferences) {
      setPreferences(user.preferences);
    } else {
      setPreferences({
        dietary_restrictions: [],
        cuisine_preferences: [],
        budget_range: "$$",
        max_distance_km: 8,
      });
    }
  }, [user]);

  const handleSavePreferences = async () => {
    if (!preferences || !tokens) return;

    try {
      setLoading(true);
      const response = await fetch(`${API_BASE}/users/me/preferences`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${tokens.access_token}`,
        },
        body: JSON.stringify(preferences),
      });

      if (response.ok) {
        Alert.alert("Success", "Preferences saved");
      } else {
        Alert.alert("Error", "Failed to save preferences");
      }
    } catch (error) {
      Alert.alert("Error", "Failed to save preferences");
    } finally {
      setLoading(false);
    }
  };

  const dietaryOptions = ["Vegetarian", "Vegan", "Gluten-free", "Dairy-free", "Nut-free"];
  const cuisineOptions = ["Italian", "Asian", "Mexican", "Indian", "Mediterranean", "American"];
  const budgetOptions = ["$", "$$", "$$$", "$$$$"] as const;

  const toggleDietary = (option: string) => {
    if (!preferences) return;
    const updated = preferences.dietary_restrictions.includes(option)
      ? preferences.dietary_restrictions.filter((d) => d !== option)
      : [...preferences.dietary_restrictions, option];
    setPreferences({ ...preferences, dietary_restrictions: updated });
  };

  const toggleCuisine = (option: string) => {
    if (!preferences) return;
    const updated = preferences.cuisine_preferences.includes(option)
      ? preferences.cuisine_preferences.filter((c) => c !== option)
      : [...preferences.cuisine_preferences, option];
    setPreferences({ ...preferences, cuisine_preferences: updated });
  };

  if (!preferences) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg, justifyContent: "center", alignItems: "center" }}>
        <Text style={{ color: colors.textSecondary }} className="text-body">Loading...</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView style={{ flex: 1, paddingHorizontal: 16 }}>
        {/* Header */}
        <View style={{ paddingTop: 24, paddingBottom: 32 }}>
          <Text style={{ color: colors.text }} className="font-dm-sans text-display-2 mb-2">
            Profile
          </Text>
          <Text style={{ color: colors.textSecondary }} className="text-body">
            {user?.name}
          </Text>
        </View>

        <View style={{ gap: 24, paddingBottom: 32 }}>
          {/* Dietary Restrictions */}
          <View>
            <Text style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase", marginBottom: 10 }}>
              Dietary Restrictions
            </Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {dietaryOptions.map((option) => {
                const selected = preferences.dietary_restrictions.includes(option);
                return (
                  <Pressable
                    key={option}
                    onPress={() => toggleDietary(option)}
                    style={{
                      paddingHorizontal: 10,
                      paddingVertical: 6,
                      borderRadius: 8,
                      backgroundColor: selected ? "rgba(217, 119, 87, 0.2)" : colors.chipBg,
                      borderWidth: 1,
                      borderColor: selected ? colors.primary : colors.chipBorder,
                    }}
                  >
                    <Text style={{ color: selected ? "#ffffff" : "rgba(255,255,255,0.75)", fontSize: 12, fontWeight: "500" }}>
                      {option}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Cuisine Preferences */}
          <View>
            <Text style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase", marginBottom: 10 }}>
              Cuisine Preferences
            </Text>
            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
              {cuisineOptions.map((option) => {
                const selected = preferences.cuisine_preferences.includes(option);
                return (
                  <Pressable
                    key={option}
                    onPress={() => toggleCuisine(option)}
                    style={{
                      paddingHorizontal: 10,
                      paddingVertical: 6,
                      borderRadius: 8,
                      backgroundColor: selected ? "rgba(217, 119, 87, 0.2)" : colors.chipBg,
                      borderWidth: 1,
                      borderColor: selected ? colors.primary : colors.chipBorder,
                    }}
                  >
                    <Text style={{ color: selected ? "#ffffff" : "rgba(255,255,255,0.75)", fontSize: 12, fontWeight: "500" }}>
                      {option}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Budget Range */}
          <View>
            <Text style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase", marginBottom: 10 }}>
              Budget Range
            </Text>
            <View style={{ flexDirection: "row", gap: 8 }}>
              {budgetOptions.map((option) => {
                const selected = preferences.budget_range === option;
                return (
                  <Pressable
                    key={option}
                    onPress={() => setPreferences({ ...preferences, budget_range: option })}
                    style={{
                      flex: 1,
                      paddingVertical: 10,
                      borderRadius: 8,
                      alignItems: "center",
                      justifyContent: "center",
                      backgroundColor: selected ? "rgba(217, 119, 87, 0.2)" : colors.chipBg,
                      borderWidth: 1,
                      borderColor: selected ? colors.primary : colors.chipBorder,
                    }}
                  >
                    <Text style={{ color: selected ? "#ffffff" : "rgba(255,255,255,0.75)", fontSize: 14, fontWeight: "500", fontFamily: "IBM Plex Mono" }}>
                      {option}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Max Distance */}
          <View>
            <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
              <Text style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase" }}>
                Max Distance
              </Text>
              <Text style={{ color: colors.primary, fontSize: 13, fontWeight: "600" }}>
                {milesFromKm(preferences.max_distance_km)} mi
              </Text>
            </View>
            <View style={{ flexDirection: "row", gap: 8 }}>
              {DISTANCE_OPTIONS_MI.map(({ mi, km }) => {
                const selected = preferences.max_distance_km === km;
                return (
                  <Pressable
                    key={mi}
                    onPress={() => setPreferences({ ...preferences, max_distance_km: km })}
                    style={{
                      flex: 1,
                      paddingVertical: 10,
                      borderRadius: 8,
                      alignItems: "center",
                      justifyContent: "center",
                      backgroundColor: selected ? "rgba(217, 119, 87, 0.2)" : colors.chipBg,
                      borderWidth: 1,
                      borderColor: selected ? colors.primary : colors.chipBorder,
                    }}
                  >
                    <Text style={{ color: selected ? "#ffffff" : "rgba(255,255,255,0.75)", fontSize: 12, fontWeight: "500" }}>
                      {mi} mi
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Appearance */}
          <View>
            <Text style={{ color: "rgba(255,255,255,0.5)", fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase", marginBottom: 10 }}>
              Appearance
            </Text>
            <View style={{ flexDirection: "row", gap: 8 }}>
              {(["light", "system", "dark"] as ThemeMode[]).map((mode) => {
                const selected = themeMode === mode;
                const label = mode.charAt(0).toUpperCase() + mode.slice(1);
                return (
                  <Pressable
                    key={mode}
                    onPress={() => setThemeMode(mode)}
                    style={{
                      flex: 1,
                      paddingVertical: 10,
                      borderRadius: 8,
                      alignItems: "center",
                      justifyContent: "center",
                      backgroundColor: selected ? "rgba(217, 119, 87, 0.2)" : colors.chipBg,
                      borderWidth: 1,
                      borderColor: selected ? colors.primary : colors.chipBorder,
                    }}
                  >
                    <Text style={{ color: selected ? "#ffffff" : "rgba(255,255,255,0.75)", fontSize: 12, fontWeight: "500" }}>
                      {label}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
          </View>

          {/* Actions */}
          <View style={{ gap: 8 }}>
            <Pressable
              onPress={handleSavePreferences}
              disabled={loading}
              style={{
                paddingVertical: 14,
                borderRadius: 10,
                alignItems: "center",
                justifyContent: "center",
                backgroundColor: colors.primary,
                opacity: loading ? 0.5 : 1,
                shadowColor: colors.primary,
                shadowOffset: { width: 0, height: 4 },
                shadowOpacity: 0.3,
                shadowRadius: 8,
                elevation: 4,
              }}
            >
              <Text className="text-white font-roboto font-medium text-body">
                {loading ? "Saving..." : "Save Preferences"}
              </Text>
            </Pressable>

            <Pressable
              onPress={logout}
              style={{
                paddingVertical: 14,
                borderRadius: 10,
                borderWidth: 1.5,
                borderColor: "#ef5350",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Text style={{ color: "#ef5350" }} className="font-roboto font-medium text-body">
                Log Out
              </Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
