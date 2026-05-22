import React, { useEffect } from "react";
import { View, Text, Image, Pressable, Modal } from "react-native";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withSequence,
  withDelay,
} from "react-native-reanimated";
import { Restaurant } from "@/types";
import { useColors } from "@/hooks/useColors";

interface MatchModalProps {
  visible: boolean;
  restaurant: Restaurant | null;
  onClose: () => void;
}

const CONFETTI_COLORS = ["#d97757", "#f5a76d", "#c7622a", "#e8a885"];

interface ParticleProps {
  size: number;
  left: number;
  color: string;
}

const Particle: React.FC<ParticleProps> = ({ size, left, color }) => {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(1);
  const translateY = useSharedValue(0);

  useEffect(() => {
    scale.value = withSpring(1, { damping: 0.6, mass: 0.5 });
    opacity.value = withSequence(withDelay(1200, withSpring(0, { damping: 0.6 })));
    translateY.value = withSequence(withDelay(1200, withSpring(-100, { damping: 0.8 })));
  }, []);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }, { translateY: translateY.value }],
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        animStyle,
        {
          position: "absolute",
          left: `${left}%`,
          top: "50%",
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: color,
        },
      ]}
    />
  );
};

const PARTICLES = Array.from({ length: 50 }, () => ({
  size: Math.random() * 8 + 4,
  left: Math.random() * 100,
  color: CONFETTI_COLORS[Math.floor(Math.random() * CONFETTI_COLORS.length)],
}));

const Confetti: React.FC = () => (
  <View style={{ position: "absolute", top: 0, left: 0, right: 0, bottom: 0 }}>
    {PARTICLES.map((p, i) => (
      <Particle key={i} size={p.size} left={p.left} color={p.color} />
    ))}
  </View>
);

export const MatchModal: React.FC<MatchModalProps> = ({ visible, restaurant, onClose }) => {
  const colors = useColors();
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);

  useEffect(() => {
    if (visible) {
      scale.value = withSpring(1, { damping: 0.7, mass: 1, stiffness: 100 });
      opacity.value = withSpring(1, { damping: 0.7 });
    } else {
      scale.value = 0;
      opacity.value = 0;
    }
  }, [visible]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  if (!restaurant) return null;

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.8)", justifyContent: "center", alignItems: "center" }}>
        <Confetti />

        <Animated.View
          style={[
            animatedStyle,
            {
              width: "85%",
              borderRadius: 16,
              borderWidth: 1,
              borderColor: colors.cardBorder,
              backgroundColor: colors.surface,
              overflow: "hidden",
            },
          ]}
        >
          {/* Image */}
          <Image
            source={{ uri: restaurant.photo_url ?? undefined }}
            style={{ width: "100%", height: 256, backgroundColor: colors.surfaceLight }}
            resizeMode="cover"
          />

          {/* Content */}
          <View style={{ padding: 24 }}>
            <Text className="text-center font-dm-sans text-display-2 text-primary mb-2">
              It's a Match!
            </Text>

            <View style={{ marginBottom: 24 }}>
              <Text style={{ color: colors.text }} className="font-dm-sans text-h1 mb-2">
                {restaurant.name}
              </Text>
              <Text style={{ color: colors.textSecondary }} className="text-body-sm mb-3">
                {restaurant.address}
              </Text>

              <View style={{ flexDirection: "row", gap: 16, marginBottom: 12 }}>
                <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                  <Text className="text-body font-medium text-primary">★</Text>
                  <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                    {restaurant.rating != null ? restaurant.rating.toFixed(1) : "—"}
                  </Text>
                </View>
                <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                  <Text className="text-body font-medium text-primary">$</Text>
                  <Text style={{ color: colors.textSecondary }} className="text-body-sm">
                    {restaurant.price_tier?.length ?? 0}
                  </Text>
                </View>
              </View>

              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
                {restaurant.cuisine_tags.slice(0, 4).map((cuisine, idx) => (
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
            </View>

            <Pressable
              onPress={onClose}
              style={{
                backgroundColor: colors.primary,
                borderRadius: 10,
                paddingVertical: 14,
                alignItems: "center",
                justifyContent: "center",
                shadowColor: colors.primary,
                shadowOffset: { width: 0, height: 4 },
                shadowOpacity: 0.3,
                shadowRadius: 8,
                elevation: 4,
              }}
            >
              <Text className="text-white font-roboto font-medium">Continue</Text>
            </Pressable>
          </View>
        </Animated.View>
      </View>
    </Modal>
  );
};
