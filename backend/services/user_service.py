from models.user import PushToken, User
from schemas.user import PreferencesUpdate, PushTokenIn


class UserService:
    async def update_preferences(self, user: User, patch: PreferencesUpdate) -> User:
        data = patch.model_dump(exclude_unset=True)
        if data:
            current = user.preferences.model_dump()
            current.update(data)
            user.preferences = user.preferences.__class__(**current)
            await user.save()
        return user

    async def add_push_token(self, user: User, payload: PushTokenIn) -> User:
        if any(t.token == payload.token for t in user.push_tokens):
            return user
        user.push_tokens.append(PushToken(token=payload.token, platform=payload.platform))
        await user.save()
        return user


def get_user_service() -> UserService:
    return UserService()
