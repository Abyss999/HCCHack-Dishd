import React from "react";
import { View, Text, Pressable, Share, Alert } from "react-native";
import * as Clipboard from "expo-clipboard";
import * as Haptics from "expo-haptics";
import Toast from "react-native-toast-message";
import { useColors } from "@/hooks/useColors";

interface CodeDisplayProps {
  code: string;
  onCopy?: () => void;
  onShare?: () => void;
}

export const CodeDisplay: React.FC<CodeDisplayProps> = ({ code, onCopy, onShare }) => {
  const colors = useColors();

  const handleCopy = async () => {
    try {
      await Clipboard.setStringAsync(code);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Toast.show({ type: "success", text1: "Copied!", text2: "Session code copied to clipboard" });
      onCopy?.();
    } catch {
      Toast.show({ type: "error", text1: "Failed to copy" });
    }
  };

  const handleShare = async () => {
    try {
      await Share.share({
        message: `Join my DishMatch session! Code: ${code}`,
        title: "DishMatch Session",
      });
      onShare?.();
    } catch {
      Alert.alert("Error", "Failed to share");
    }
  };

  return (
    <View style={{ alignItems: "center", gap: 20 }}>
      {/* Code boxes */}
      <View style={{ flexDirection: "row", gap: 8 }}>
        {code.split("").map((char, index) => (
          <View
            key={index}
            style={{
              width: 50,
              height: 50,
              borderRadius: 10,
              borderWidth: 1.5,
              borderColor: "rgba(217, 119, 87, 0.4)",
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: colors.surfaceLight,
            }}
          >
            <Text
              style={{
                fontFamily: "IBM Plex Mono",
                fontSize: 18,
                fontWeight: "600",
                color: colors.primary,
              }}
            >
              {char}
            </Text>
          </View>
        ))}
      </View>

      {/* Action buttons */}
      <View style={{ flexDirection: "row", gap: 10 }}>
        <Pressable
          onPress={handleCopy}
          style={{
            flex: 1,
            paddingHorizontal: 16,
            paddingVertical: 10,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: colors.primary,
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Text style={{ color: colors.primary }} className="font-roboto font-medium text-body-sm">Copy</Text>
        </Pressable>
        <Pressable
          onPress={handleShare}
          style={{
            flex: 1,
            paddingHorizontal: 16,
            paddingVertical: 10,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: colors.primary,
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <Text style={{ color: colors.primary }} className="font-roboto font-medium text-body-sm">Share</Text>
        </Pressable>
      </View>
    </View>
  );
};
