import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  SafeAreaView,
  ScrollView,
  Pressable,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSession } from "@/hooks/useSession";
import { useWebSocket } from "@/hooks/useWebSocket";
import { useAuth } from "@/hooks/useAuth";
import { useColors } from "@/hooks/useColors";
import * as Haptics from "expo-haptics";
import Toast from "react-native-toast-message";
import { CodeDisplay } from "@/components/CodeDisplay";
import { Avatar } from "@/components/ui/Button";
import { SessionMember } from "@/types";

export default function LobbyScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const router = useRouter();
  const { tokens, user } = useAuth();
  const { session, getSession, startSwiping, loading } = useSession(tokens);
  const colors = useColors();
  const [members, setMembers] = useState<SessionMember[]>([]);

  useEffect(() => {
    if (sessionId && tokens) {
      getSession(sessionId);
    }
  }, [sessionId, tokens]);

  useEffect(() => {
    if (session) {
      setMembers(session.members);
    }
  }, [session]);

  const wsHandlers = {
    onMemberJoined: (payload: any) => {
      setMembers((prev) => {
        const exists = prev.find((m) => m.user_id === payload.user_id);
        if (exists) return prev;
        return [...prev, payload];
      });
    },
    onPhaseChange: (payload: any) => {
      if (payload.phase === "swiping") {
        router.push(`/session/swipe?sessionId=${sessionId}`);
      }
    },
  };

  useWebSocket(sessionId || "", tokens?.access_token || "", wsHandlers);

  const isHost = user?.id === session?.host_user_id;

  const handleStartSwiping = async () => {
    if (!sessionId || members.length < 2) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      Toast.show({ type: "error", text1: "Not enough players", text2: "At least 2 members needed" });
      return;
    }

    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
      await startSwiping(sessionId);
      router.push(`/session/swipe?sessionId=${sessionId}`);
    } catch {
      Toast.show({ type: "error", text1: "Failed to start", text2: "Please try again" });
    }
  };

  if (!session) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg, justifyContent: "center", alignItems: "center" }}>
        <Text style={{ color: colors.textSecondary }} className="text-body">Loading...</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView style={{ flex: 1 }}>
        {/* Header */}
        <View style={{ paddingHorizontal: 16, paddingTop: 24, paddingBottom: 32 }}>
          <Text style={{ color: colors.text }} className="font-dm-sans text-display-2 mb-2">
            Your Session
          </Text>
          <Text style={{ color: colors.textSecondary }} className="text-body">
            Invite friends to join
          </Text>
        </View>

        {/* Session code */}
        <View style={{
          paddingHorizontal: 16,
          paddingVertical: 32,
          backgroundColor: colors.surface,
          borderRadius: 12,
          borderWidth: 1,
          borderColor: colors.cardBorder,
          marginHorizontal: 16,
          marginBottom: 32,
        }}>
          <Text style={{ color: colors.textSecondary }} className="text-body-sm text-center mb-4">
            Share this code
          </Text>
          <CodeDisplay code={session.code} />
        </View>

        {/* Members section */}
        <View style={{ paddingHorizontal: 16, marginBottom: 32 }}>
          <Text style={{ color: colors.text }} className="font-dm-sans text-h2 mb-4">
            Members ({members.length})
          </Text>

          {members.length === 0 ? (
            <Text style={{ color: colors.textSecondary }} className="text-body-sm">
              Waiting for friends to join...
            </Text>
          ) : (
            <View style={{ gap: 12 }}>
              {members.map((member) => (
                <View
                  key={member.user_id}
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: 12,
                    padding: 12,
                    backgroundColor: colors.surface,
                    borderRadius: 10,
                    borderWidth: 1,
                    borderColor: colors.cardBorder,
                  }}
                >
                  <Avatar
                    name={member.name}
                    userId={member.user_id}
                    size="md"
                    online={true}
                  />
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: colors.text }} className="text-body">
                      {member.name}
                    </Text>
                    <Text style={{ color: colors.textTertiary }} className="text-caption">
                      {member.user_id === user?.id ? "You" : "Joined"}
                    </Text>
                  </View>
                </View>
              ))}
            </View>
          )}
        </View>

        {/* Start button (host only) */}
        {isHost && (
          <View style={{ paddingHorizontal: 16, paddingBottom: 32 }}>
            <Pressable
              onPress={handleStartSwiping}
              disabled={loading || members.length < 2}
              style={{
                paddingVertical: 14,
                borderRadius: 10,
                alignItems: "center",
                justifyContent: "center",
                backgroundColor: members.length >= 2 ? colors.primary : colors.textTertiary,
                opacity: loading || members.length < 2 ? 0.5 : 1,
                shadowColor: colors.primary,
                shadowOffset: { width: 0, height: 4 },
                shadowOpacity: members.length >= 2 ? 0.3 : 0,
                shadowRadius: 8,
                elevation: members.length >= 2 ? 4 : 0,
              }}
            >
              <Text className="text-white font-dm-sans text-h2">
                {loading ? "Starting..." : "Start Swiping"}
              </Text>
            </Pressable>
            {members.length < 2 && (
              <Text style={{ color: colors.textTertiary }} className="text-caption text-center mt-2">
                Need at least 2 members to start
              </Text>
            )}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
