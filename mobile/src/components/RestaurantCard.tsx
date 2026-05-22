import React from "react";
import { View, Text, Image, Pressable } from "react-native";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  runOnJS,
  interpolate,
  Extrapolation,
} from "react-native-reanimated";
import * as Haptics from "expo-haptics";
import { Restaurant } from "@/types";
import { useColors } from "@/hooks/useColors";

interface RestaurantCardProps {
  restaurant: Restaurant;
  onSwipeLeft: () => void;
  onSwipeRight: () => void;
  style?: any;
}

const SWIPE_THRESHOLD = 80;

export const RestaurantCard: React.FC<RestaurantCardProps> = ({
  restaurant,
  onSwipeLeft,
  onSwipeRight,
  style,
}) => {
  const colors = useColors();
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const rotateZ = useSharedValue(0);
  const opacity = useSharedValue(1);

  const triggerHaptic = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  };

  const pan = Gesture.Pan()
    .onUpdate((e) => {
      translateX.value = e.translationX;
      translateY.value = e.translationY * 0.2;
      rotateZ.value = interpolate(
        e.translationX,
        [-200, 200],
        [-18, 18],
        Extrapolation.CLAMP
      );
    })
    .onEnd((e) => {
      if (e.translationX > SWIPE_THRESHOLD) {
        translateX.value = withSpring(600, { damping: 14 });
        rotateZ.value = withSpring(20);
        opacity.value = withSpring(0);
        runOnJS(triggerHaptic)();
        runOnJS(onSwipeRight)();
      } else if (e.translationX < -SWIPE_THRESHOLD) {
        translateX.value = withSpring(-600, { damping: 14 });
        rotateZ.value = withSpring(-20);
        opacity.value = withSpring(0);
        runOnJS(triggerHaptic)();
        runOnJS(onSwipeLeft)();
      } else {
        translateX.value = withSpring(0, { damping: 15 });
        translateY.value = withSpring(0, { damping: 15 });
        rotateZ.value = withSpring(0, { damping: 15 });
      }
    });

  const cardStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { rotateZ: `${rotateZ.value}deg` },
    ],
    opacity: opacity.value,
  }));

  const likeOverlayStyle = useAnimatedStyle(() => ({
    opacity: interpolate(translateX.value, [0, SWIPE_THRESHOLD], [0, 1], Extrapolation.CLAMP),
  }));

  const passOverlayStyle = useAnimatedStyle(() => ({
    opacity: interpolate(translateX.value, [-SWIPE_THRESHOLD, 0], [1, 0], Extrapolation.CLAMP),
  }));

  const priceDisplay = restaurant.price_tier?.length ?? 0;
  const ratingDisplay = restaurant.rating != null ? restaurant.rating.toFixed(1) : "—";

  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={[cardStyle, style]}>
        <View
          style={{
            backgroundColor: colors.surface,
            borderRadius: 12,
            borderWidth: 1,
            borderColor: colors.cardBorder,
            overflow: "hidden",
            shadowColor: "#000",
            shadowOffset: { width: 0, height: 4 },
            shadowOpacity: 0.3,
            shadowRadius: 12,
            elevation: 8,
          }}
        >
          {/* Image */}
          <View style={{ position: "relative" }}>
            <Image
              source={{ uri: restaurant.photo_url ?? undefined }}
              style={{ width: "100%", height: 320, backgroundColor: colors.surfaceLight }}
              resizeMode="cover"
            />

            {/* Like overlay */}
            <Animated.View
              style={[
                likeOverlayStyle,
                {
                  position: "absolute",
                  inset: 0,
                  backgroundColor: "rgba(76, 175, 80, 0.35)",
                  justifyContent: "center",
                  alignItems: "flex-start",
                  paddingLeft: 24,
                },
              ]}
              pointerEvents="none"
            >
              <View style={{
                borderWidth: 3,
                borderColor: "#4caf50",
                borderRadius: 8,
                paddingHorizontal: 12,
                paddingVertical: 6,
                transform: [{ rotate: "-15deg" }],
              }}>
                <Text style={{ color: "#4caf50", fontSize: 32, fontWeight: "800" }}>LIKE</Text>
              </View>
            </Animated.View>

            {/* Pass overlay */}
            <Animated.View
              style={[
                passOverlayStyle,
                {
                  position: "absolute",
                  inset: 0,
                  backgroundColor: "rgba(239, 83, 80, 0.35)",
                  justifyContent: "center",
                  alignItems: "flex-end",
                  paddingRight: 24,
                },
              ]}
              pointerEvents="none"
            >
              <View style={{
                borderWidth: 3,
                borderColor: "#ef5350",
                borderRadius: 8,
                paddingHorizontal: 12,
                paddingVertical: 6,
                transform: [{ rotate: "15deg" }],
              }}>
                <Text style={{ color: "#ef5350", fontSize: 32, fontWeight: "800" }}>PASS</Text>
              </View>
            </Animated.View>
          </View>

          {/* Info */}
          <View style={{ padding: 16 }}>
            <View style={{ marginBottom: 10 }}>
              <Text style={{ color: colors.text }} className="font-dm-sans text-h1 mb-1">
                {restaurant.name}
              </Text>
              <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                {restaurant.address}
              </Text>
            </View>

            <View style={{ flexDirection: "row", gap: 16, marginBottom: 12 }}>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                <Text className="text-body font-medium text-primary">★</Text>
                <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                  {ratingDisplay}
                </Text>
              </View>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                <Text className="text-body font-medium text-primary">$</Text>
                <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                  {priceDisplay}
                </Text>
              </View>
              {restaurant.lat && (
                <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                  0.3 mi
                </Text>
              )}
            </View>

            <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8, marginBottom: 14 }}>
              {restaurant.cuisine_tags.slice(0, 3).map((cuisine, idx) => (
                <View
                  key={idx}
                  style={{
                    paddingHorizontal: 9,
                    paddingVertical: 4,
                    borderRadius: 6,
                    backgroundColor: colors.chipBg,
                    borderWidth: 1,
                    borderColor: colors.chipBorder,
                  }}
                >
                  <Text style={{ color: "rgba(255,255,255,0.65)" }} className="text-caption-sm font-medium">
                    {cuisine}
                  </Text>
                </View>
              ))}
            </View>

            {/* Action buttons */}
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Pressable
                onPress={onSwipeLeft}
                style={{
                  flex: 1,
                  paddingVertical: 12,
                  borderRadius: 10,
                  borderWidth: 1.5,
                  borderColor: "#ef5350",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Text style={{ color: "#ef5350", fontSize: 14, fontWeight: "600" }}>Pass</Text>
              </Pressable>
              <Pressable
                onPress={onSwipeRight}
                style={{
                  flex: 1,
                  paddingVertical: 12,
                  borderRadius: 10,
                  alignItems: "center",
                  justifyContent: "center",
                  backgroundColor: "#4caf50",
                  shadowColor: "#4caf50",
                  shadowOffset: { width: 0, height: 4 },
                  shadowOpacity: 0.3,
                  shadowRadius: 8,
                  elevation: 4,
                }}
              >
                <Text style={{ color: "#ffffff", fontSize: 14, fontWeight: "600" }}>Like ❤️</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Animated.View>
    </GestureDetector>
  );
};
