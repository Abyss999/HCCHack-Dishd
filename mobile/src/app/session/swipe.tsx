import React, { useEffect, useState } from "react";
import {
  View,
  Text,
  SafeAreaView,
  Pressable,
} from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import * as Haptics from "expo-haptics";
import Toast from "react-native-toast-message";
import { useSession } from "@/hooks/useSession";
import { useWebSocket } from "@/hooks/useWebSocket";
import { useAuth } from "@/hooks/useAuth";
import { useColors } from "@/hooks/useColors";
import { SwipeStack } from "@/components/SwipeStack";
import { MatchModal } from "@/components/MatchModal";
import { Restaurant } from "@/types";

export default function SwipeScreen() {
  const { sessionId } = useLocalSearchParams<{ sessionId: string }>();
  const router = useRouter();
  const { tokens } = useAuth();
  const { restaurants, getRestaurants, submitSwipe, loading } = useSession(tokens);
  const colors = useColors();
  const [swipeCount, setSwipeCount] = useState(0);
  const [memberProgress, setMemberProgress] = useState<Record<string, number>>({});
  const [matchedRestaurant, setMatchedRestaurant] = useState<Restaurant | null>(null);
  const [showMatch, setShowMatch] = useState(false);

  useEffect(() => {
    if (sessionId && tokens) {
      getRestaurants(sessionId);
    }
  }, [sessionId, tokens]);

  const wsHandlers = {
    onSwipeProgress: (payload: any) => {
      setMemberProgress((prev) => ({
        ...prev,
        [payload.user_id]: payload.swipe_count,
      }));
    },
    onInstantMatch: (payload: any) => {
      setMatchedRestaurant(payload.restaurant);
      setShowMatch(true);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    },
    onPhaseChange: (payload: any) => {
      if (payload.phase === "results") {
        router.push(`/session/results?sessionId=${sessionId}`);
      }
    },
  };

  useWebSocket(sessionId || "", tokens?.access_token || "", wsHandlers);

  const handleSwipe = async (restaurantId: string, direction: "yes" | "no") => {
    try {
      await submitSwipe(sessionId || "", restaurantId, direction);
      const next = swipeCount + 1;
      setSwipeCount(next);
      if (next === 5) {
        Toast.show({ type: "success", text1: "You can see results now", text2: "Or keep swiping for better matches" });
      }
    } catch {
      Toast.show({ type: "error", text1: "Swipe failed", text2: "Try again" });
    }
  };

  const handleMatchClose = () => {
    setShowMatch(false);
    router.push(`/session/results?sessionId=${sessionId}`);
  };

  const minSwipes = 5;
  const maxSwipes = 10;
  const canSeeResults = swipeCount >= minSwipes;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      {/* Progress */}
      <View style={{ paddingHorizontal: 16, paddingVertical: 16, gap: 8 }}>
        <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
          <Text style={{ color: colors.textSecondary }} className="text-body-sm">
            Your swipes: {swipeCount}/{maxSwipes}
          </Text>
          {canSeeResults && (
            <Pressable
              onPress={() => {
                Haptics.selectionAsync();
                router.push(`/session/results?sessionId=${sessionId}`);
              }}
              style={{
                paddingHorizontal: 12,
                paddingVertical: 4,
                borderRadius: 999,
                borderWidth: 1,
                borderColor: colors.primary,
              }}
            >
              <Text className="text-caption text-primary font-medium">
                See Results
              </Text>
            </Pressable>
          )}
        </View>

        <View style={{ height: 3, backgroundColor: colors.progressBg, borderRadius: 2, overflow: "hidden" }}>
          <View
            style={{ height: "100%", backgroundColor: colors.primary, borderRadius: 2, width: `${(swipeCount / maxSwipes) * 100}%` }}
          />
        </View>

        <View style={{ flexDirection: "row", gap: 4 }}>
          {Object.entries(memberProgress).map(([userId, count]) => (
            <View
              key={userId}
              style={{ flex: 1, height: 2, backgroundColor: "rgba(217, 119, 87, 0.15)", borderRadius: 1, overflow: "hidden" }}
            >
              <View
                style={{ height: "100%", backgroundColor: colors.primaryLight, borderRadius: 1, width: `${(count / maxSwipes) * 100}%` }}
              />
            </View>
          ))}
        </View>
      </View>

      {/* Swipe stack */}
      <View style={{ flex: 1 }}>
        {restaurants.length === 0 ? (
          <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
            <Text style={{ color: colors.text }} className="text-h1">
              Loading restaurants...
            </Text>
          </View>
        ) : (
          <SwipeStack
            restaurants={restaurants}
            onSwipe={handleSwipe}
            onStackEmpty={() => {
              if (!canSeeResults) {
                Toast.show({
                  type: "error",
                  text1: "Keep going!",
                  text2: `Swipe ${minSwipes - swipeCount} more to see results`,
                });
              }
            }}
          />
        )}
      </View>

      <MatchModal
        visible={showMatch}
        restaurant={matchedRestaurant}
        onClose={handleMatchClose}
      />
    </SafeAreaView>
  );
}
