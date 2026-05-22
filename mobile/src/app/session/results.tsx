import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  SafeAreaView,
  ScrollView,
  Image,
  Pressable,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useSession } from "@/hooks/useSession";
import { useWebSocket } from "@/hooks/useWebSocket";
import { useAuth } from "@/hooks/useAuth";
import { SessionResult } from "@/types";

export default function ResultsScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const router = useRouter();
  const { tokens } = useAuth();
  const { results, getResults, loading } = useSession(tokens);
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
      <SafeAreaView className="flex-1 bg-neutral-bg justify-center items-center">
        <Text className="text-body text-neutral-text-secondary">
          Calculating results...
        </Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-neutral-bg">
      <ScrollView className="flex-1">
        {/* Header */}
        <View className="px-4 pt-6 pb-8">
          <Text className="font-dm-sans text-display-2 text-neutral-text mb-2">
            Top Results
          </Text>
          <Text className="text-body text-neutral-text-secondary">
            Based on everyone's votes
          </Text>
        </View>

        {/* Results list */}
        <View className="px-4 gap-4 pb-8">
          {displayResults.map((result, index) => (
            <View
              key={result.restaurant.id}
              className="rounded-lg overflow-hidden"
              style={{
                backgroundColor: "#262626",
              }}
            >
              {/* Rank badge + Image */}
              <View className="relative h-48">
                <Image
                  source={{ uri: result.restaurant.photo_url ?? undefined }}
                  className="w-full h-full bg-neutral-surface"
                  resizeMode="cover"
                />
                {/* Rank badge */}
                <View
                  className="absolute top-3 right-3 rounded-full w-12 h-12 items-center justify-center"
                  style={{
                    backgroundColor: index === 0 ? "#f5a76d" : "#3d3d3d",
                  }}
                >
                  <Text
                    className="font-dm-sans font-bold text-h2"
                    style={{
                      color: index === 0 ? "#1a1a1a" : "#ffffff",
                    }}
                  >
                    #{index + 1}
                  </Text>
                </View>
              </View>

              {/* Info section */}
              <View className="p-4">
                {/* Restaurant name + rating */}
                <View className="mb-3">
                  <Text className="font-dm-sans text-h1 text-neutral-text mb-1">
                    {result.restaurant.name}
                  </Text>
                  <View className="flex-row items-center gap-2">
                    <Text className="text-primary text-body font-medium">★</Text>
                    <Text className="text-body-sm text-neutral-text-secondary">
                      {result.restaurant.rating != null
                        ? result.restaurant.rating.toFixed(1)
                        : "—"}{" "}
                      • {result.restaurant.price_tier ?? "—"}
                    </Text>
                  </View>
                </View>

                {/* Address */}
                <Text className="text-body-sm text-neutral-text-secondary mb-4">
                  {result.restaurant.address}
                </Text>

                {/* Vote score */}
                <View className="mb-3">
                  <View className="flex-row justify-between items-center mb-2">
                    <Text className="text-body-sm font-medium text-neutral-text">
                      Agreement
                    </Text>
                    <Text className="text-h2 font-bold text-primary">
                      {result.score_pct.toFixed(0)}%
                    </Text>
                  </View>

                  {/* Progress bar */}
                  <View className="h-2 bg-neutral-surface rounded-full overflow-hidden">
                    <View
                      className="h-full bg-primary rounded-full"
                      style={{
                        width: `${result.score_pct}%`,
                      }}
                    />
                  </View>

                  {/* Vote count */}
                  <Text className="text-caption text-neutral-text-tertiary mt-1">
                    {result.yes_count} of {result.total} members
                  </Text>
                </View>

                {/* Cuisines */}
                <View className="flex-row flex-wrap gap-2">
                  {result.restaurant.cuisine_tags.slice(0, 3).map((cuisine) => (
                    <View
                      key={cuisine}
                      className="px-2 py-1 rounded-full bg-neutral-surface-light"
                    >
                      <Text className="text-caption text-neutral-text-secondary">
                        {cuisine}
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            </View>
          ))}
        </View>

        {/* Action buttons */}
        <View className="px-4 pb-8 gap-2">
          <Pressable
            className="py-3 rounded-lg items-center justify-center bg-primary"
            onPress={handleReturnHome}
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
