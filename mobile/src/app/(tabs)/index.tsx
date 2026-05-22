import React, { useState } from "react";
import {
  View,
  Text,
  Pressable,
  TextInput,
  ScrollView,
  SafeAreaView,
} from "react-native";
import { useRouter } from "expo-router";
import Toast from "react-native-toast-message";
import { useAuth } from "@/hooks/useAuth";
import { useSession } from "@/hooks/useSession";
import { useColors } from "@/hooks/useColors";

export default function HomeScreen() {
  const router = useRouter();
  const { user, logout } = useAuth();
  const { tokens } = useAuth();
  const { createSession, joinSession, loading } = useSession(tokens);
  const colors = useColors();

  const [showJoinCode, setShowJoinCode] = useState(false);
  const [joinCode, setJoinCode] = useState("");

  const handleCreateSession = async () => {
    try {
      const session = await createSession(40.7128, -74.006);
      router.push(`/session/lobby?sessionId=${session.id}`);
    } catch {
      Toast.show({ type: "error", text1: "Failed to create session", text2: "Please try again" });
    }
  };

  const handleJoinSession = async (code: string) => {
    try {
      const session = await joinSession(code.toUpperCase());
      router.push(`/session/lobby?sessionId=${session.id}`);
    } catch {
      Toast.show({ type: "error", text1: "Couldn't join session", text2: "Check the code and try again" });
    }
  };

  const handleCodeChange = (text: string) => {
    const upper = text.toUpperCase().slice(0, 4);
    setJoinCode(upper);
    if (upper.length === 4) {
      handleJoinSession(upper);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView style={{ flex: 1 }}>
        {/* Header */}
        <View style={{
          paddingHorizontal: 16,
          paddingTop: 20,
          paddingBottom: 14,
          flexDirection: "row",
          justifyContent: "space-between",
          alignItems: "center",
          borderBottomWidth: 1,
          borderBottomColor: "rgba(255,255,255,0.06)",
          marginBottom: 16,
        }}>
          <View>
            <Text style={{ color: colors.text, fontFamily: "DM Sans", fontSize: 15, fontWeight: "600" }}>
              Welcome back
            </Text>
            <Text style={{ color: "rgba(255,255,255,0.45)", fontSize: 12 }}>
              {user?.name}
            </Text>
          </View>
          <Pressable
            onPress={logout}
            style={{
              paddingHorizontal: 12,
              paddingVertical: 6,
              borderRadius: 6,
              borderWidth: 1,
              borderColor: "rgba(255,255,255,0.2)",
            }}
          >
            <Text style={{ color: "rgba(255,255,255,0.6)", fontSize: 12 }}>
              Logout
            </Text>
          </Pressable>
        </View>

        {/* Main actions */}
        <View style={{ paddingHorizontal: 16, gap: 12, paddingBottom: 24 }}>
          <Pressable
            onPress={handleCreateSession}
            disabled={loading}
            style={{
              paddingVertical: 24,
              borderRadius: 12,
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: colors.primary,
              opacity: loading ? 0.5 : 1,
              shadowColor: colors.primary,
              shadowOffset: { width: 0, height: 4 },
              shadowOpacity: 0.3,
              shadowRadius: 12,
              elevation: 4,
            }}
          >
            <Text className="font-dm-sans text-h2 text-white mb-1">
              {loading ? "Creating..." : "Create Session"}
            </Text>
            <Text style={{ color: "rgba(255,255,255,0.7)" }} className="text-body-sm">
              Start a new group decision
            </Text>
          </Pressable>

          <View style={{ flexDirection: "row", alignItems: "center", gap: 12, marginVertical: 8 }}>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
            <Text style={{ color: colors.textTertiary }} className="text-caption">or</Text>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
          </View>

          <Pressable
            onPress={() => setShowJoinCode(!showJoinCode)}
            style={{
              paddingVertical: 24,
              borderRadius: 12,
              alignItems: "center",
              justifyContent: "center",
              borderWidth: 1.5,
              borderColor: colors.primary,
            }}
          >
            <Text className="font-dm-sans text-h2 text-primary mb-1">
              Join Session
            </Text>
            <Text style={{ color: colors.primary + "b3" }} className="text-body-sm">
              Enter a 4-digit code
            </Text>
          </Pressable>
        </View>

        {/* Join code input */}
        {showJoinCode && (
          <View style={{ paddingHorizontal: 16, paddingVertical: 24, gap: 12 }}>
            <Text style={{ color: colors.textSecondary }} className="text-body-sm">
              Enter the 4-character session code
            </Text>
            <TextInput
              placeholder="XXXX"
              placeholderTextColor={colors.placeholderText}
              value={joinCode}
              onChangeText={handleCodeChange}
              maxLength={4}
              autoFocus
              editable={!loading}
              style={{
                color: colors.text,
                fontFamily: "IBM Plex Mono",
                fontSize: 24,
                letterSpacing: 8,
                paddingVertical: 12,
                paddingHorizontal: 12,
                borderRadius: 10,
                backgroundColor: colors.inputBg,
                borderWidth: 1.5,
                borderColor: colors.primary,
                textAlign: "center",
              }}
            />
            {loading && (
              <Text style={{ color: colors.textSecondary, textAlign: "center" }} className="text-body-sm">
                Joining...
              </Text>
            )}
          </View>
        )}

        {/* How it works */}
        <View style={{ paddingHorizontal: 16, paddingBottom: 32 }}>
          <View style={{
            backgroundColor: "rgba(217, 119, 87, 0.06)",
            borderLeftWidth: 3,
            borderLeftColor: "rgba(217, 119, 87, 0.4)",
            borderRadius: 6,
            padding: 14,
          }}>
            <Text style={{ color: "rgba(217, 119, 87, 0.9)", fontSize: 12, fontWeight: "600", marginBottom: 8 }}>
              How it works
            </Text>
            {[
              "Create or join a session with friends",
              "Swipe yes/no on nearby restaurants",
              "Instant match when everyone agrees",
              "See the top 3 options otherwise",
            ].map((tip, i) => (
              <Text key={tip} style={{ color: "rgba(255,255,255,0.5)", fontSize: 12, lineHeight: 18, marginBottom: i < 3 ? 4 : 0 }}>
                • {tip}
              </Text>
            ))}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
