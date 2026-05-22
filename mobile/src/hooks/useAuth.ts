import { useCallback, useEffect, useState } from "react";
import { Platform } from "react-native";
import { useRouter } from "expo-router";
import * as SecureStore from "expo-secure-store";
import { AuthTokens, User } from "@/types";

const API_BASE = process.env.EXPO_PUBLIC_API_URL || "http://localhost:8000";

// SecureStore doesn't work on web — use localStorage as fallback
const storage = {
  get: async (key: string): Promise<string | null> => {
    if (Platform.OS === "web") {
      return localStorage.getItem(key);
    }
    return SecureStore.getItemAsync(key);
  },
  set: async (key: string, value: string): Promise<void> => {
    if (Platform.OS === "web") {
      localStorage.setItem(key, value);
      return;
    }
    await SecureStore.setItemAsync(key, value);
  },
  delete: async (key: string): Promise<void> => {
    if (Platform.OS === "web") {
      localStorage.removeItem(key);
      return;
    }
    await SecureStore.deleteItemAsync(key);
  },
};

export const useAuth = () => {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [tokens, setTokens] = useState<AuthTokens | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const stored = await storage.get("auth_tokens");
        if (stored) {
          const parsed = JSON.parse(stored);
          setTokens(parsed);
          const res = await fetch(`${API_BASE}/users/me`, {
            headers: { Authorization: `Bearer ${parsed.access_token}` },
          });
          if (res.ok) {
            setUser(await res.json());
          } else if (res.status === 401) {
            await refreshTokenInternal(parsed.refresh_token);
          }
        }
      } catch (error) {
        console.error("Failed to restore auth:", error);
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const refreshTokenInternal = useCallback(async (refreshToken: string) => {
    try {
      const res = await fetch(`${API_BASE}/auth/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      if (res.ok) {
        const newTokens = await res.json();
        setTokens(newTokens);
        await storage.set("auth_tokens", JSON.stringify(newTokens));
        return newTokens;
      } else {
        await logoutInternal();
        return null;
      }
    } catch (error) {
      console.error("Token refresh failed:", error);
      await logoutInternal();
      return null;
    }
  }, []);

  const logoutInternal = useCallback(async () => {
    await storage.delete("auth_tokens");
    setTokens(null);
    setUser(null);
  }, []);

  const login = useCallback(
    async (email: string, password: string) => {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      if (!res.ok) throw new Error("Login failed");
      const data = await res.json();
      setTokens(data);
      await storage.set("auth_tokens", JSON.stringify(data));
      const userRes = await fetch(`${API_BASE}/users/me`, {
        headers: { Authorization: `Bearer ${data.access_token}` },
      });
      if (userRes.ok) setUser(await userRes.json());
      router.replace("/(tabs)");
    },
    [router]
  );

  const signup = useCallback(
    async (email: string, password: string, name: string) => {
      const res = await fetch(`${API_BASE}/auth/signup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, name }),
      });
      if (!res.ok) throw new Error("Signup failed");
      const data = await res.json();
      setTokens(data);
      await storage.set("auth_tokens", JSON.stringify(data));
      setUser({ id: "", email, name });
      router.replace("/(tabs)");
    },
    [router]
  );

  const logout = useCallback(async () => {
    await logoutInternal();
    router.replace("/auth/login");
  }, [router, logoutInternal]);

  const refreshToken = useCallback(async () => {
    if (!tokens?.refresh_token) return;
    await refreshTokenInternal(tokens.refresh_token);
  }, [tokens, refreshTokenInternal]);

  return { user, tokens, isLoading, login, signup, logout, refreshToken };
};

export const useApi = (tokens: AuthTokens | null) => {
  return useCallback(
    async (url: string, options: RequestInit = {}) => {
      const headers = {
        "Content-Type": "application/json",
        ...(tokens && { Authorization: `Bearer ${tokens.access_token}` }),
        ...options.headers,
      };
      const response = await fetch(`${API_BASE}${url}`, { ...options, headers });
      if (response.status === 401 && tokens) {
        throw new Error("Unauthorized");
      }
      return response;
    },
    [tokens]
  );
};
