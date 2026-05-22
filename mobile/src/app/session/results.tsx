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
import { SessionResult } from "@/types";

export default function ResultsScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const router = useRouter();
  const { tokens } = useAuth();
  const { results, getResults, loading } = useSession(tokens);
  const colors = useColors();
  const [displayResults, setDisplayResults] = useState<SessionResult[]>([]);

  useEffect(() => {
    if (sessionId && tokens) {
      getResults(sessionId);
    }
  }, [sessionId, tokens]);

  useEffect(() => {
    if (results.length > 0) {
      setDisplayResults(results);
    }
  }, [results]);

  const wsHandlers = {
    onTop3Ready: (payload: any) => {
      setDisplayResults(payload.results);
    },
  };

  useWebSocket(sessionId || "", tokens?.access_token || "", wsHandlers);

  const handleReturnHome = () => {
    router.replace("/(tabs)");
  };

  if (loading && displayResults.length === 0) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg, justifyContent: "center", alignItems: "center" }}>
        <Text style={{ color: colors.textSecondary }} className="text-body">
          Calculating results...
        </Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <ScrollView style={{ flex: 1 }}>
        {/* Header */}
        <View style={{ paddingHorizontal: 16, paddingTop: 24, paddingBottom: 32 }}>
          <Text style={{ color: colors.text }} className="font-dm-sans text-display-2 mb-2">
            Top Results
          </Text>
          <Text style={{ color: colors.textSecondary }} className="text-body">
            Based on everyone's votes
          </Text>
        </View>

        {/* Results list */}
        <View style={{ paddingHorizontal: 16, gap: 10, paddingBottom: 32 }}>
          {displayResults.map((result, index) => {
            const medal = ["🥇", "🥈", "🥉"][index] ?? `#${index + 1}`;
            return (
              <View
                key={result.restaurant.id}
                style={{
                  flexDirection: "row",
                  gap: 10,
                  alignItems: "flex-start",
                  padding: 12,
                  borderRadius: 10,
                  backgroundColor: colors.surface,
                  borderWidth: 1,
                  borderColor: colors.cardBorder,
                }}
              >
                {/* Rank badge */}
                <View
                  style={{
                    width: 40,
                    height: 40,
                    borderRadius: 8,
                    alignItems: "center",
                    justifyContent: "center",
                    backgroundColor: "rgba(217, 119, 87, 0.2)",
                    flexShrink: 0,
                  }}
                >
                  <Text style={{ fontSize: index < 3 ? 20 : 16, fontWeight: "700", color: colors.primary }}>
                    {medal}
                  </Text>
                </View>

                {/* Content */}
                <View style={{ flex: 1 }}>
                  <Text style={{ color: colors.text, fontSize: 14, fontWeight: "600", marginBottom: 4 }}>
                    {result.restaurant.name}
                  </Text>
                  <View style={{ flexDirection: "row", gap: 12, marginBottom: 8 }}>
                    <Text style={{ color: colors.textTertiary, fontSize: 12 }}>
                      {result.yes_count} of {result.total} votes
                    </Text>
                    <Text style={{ color: colors.textTertiary, fontSize: 12 }}>
                      {result.score_pct.toFixed(0)}%
                    </Text>
                    {result.restaurant.rating != null && (
                      <Text style={{ color: colors.textTertiary, fontSize: 12 }}>
                        ★ {result.restaurant.rating.toFixed(1)}
                      </Text>
                    )}
                  </View>
                  <View style={{ height: 2, backgroundColor: colors.progressBg, borderRadius: 1, overflow: "hidden" }}>
                    <View
                      style={{ height: "100%", backgroundColor: colors.primary, borderRadius: 1, width: `${result.score_pct}%` }}
                    />
                  </View>
                </View>
              </View>
            );
          })}
        </View>

        {/* Action */}
        <View style={{ paddingHorizontal: 16, paddingBottom: 32, gap: 8 }}>
          <Pressable
            onPress={handleReturnHome}
            style={{
              paddingVertical: 14,
              borderRadius: 10,
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: colors.primary,
              shadowColor: colors.primary,
              shadowOffset: { width: 0, height: 4 },
              shadowOpacity: 0.3,
              shadowRadius: 8,
              elevation: 4,
            }}
          >
            <Text className="text-white font-dm-sans text-h2">
              Start New Session
            </Text>
          </Pressable>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
