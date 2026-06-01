"""
FCM Push Notification Service — Firebase Cloud Messaging.
"""

import logging
from typing import Any

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Firebase admin will be lazy-initialized
_firebase_app = None


def _init_firebase():
    """Initialize Firebase Admin SDK (lazy)."""
    global _firebase_app
    if _firebase_app is not None:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        if settings.firebase_credentials_path:
            cred = credentials.Certificate(settings.firebase_credentials_path)
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            # Use default credentials (e.g., on GCP)
            _firebase_app = firebase_admin.initialize_app()
        logger.info("Firebase Admin SDK initialized successfully")
    except Exception as e:
        logger.warning(f"Firebase initialization failed: {e}. Push notifications disabled.")


class FCMService:
    """Firebase Cloud Messaging push notification service."""

    @staticmethod
    async def send_push(
        fcm_token: str,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> bool:
        """
        Send a push notification to a single device.
        Returns True if sent successfully.
        """
        _init_firebase()

        try:
            from firebase_admin import messaging

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=fcm_token,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        sound="default",
                        channel_id="tostamp_stamps",
                    ),
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="default",
                            badge=1,
                        ),
                    ),
                ),
            )
            response = messaging.send(message)
            logger.info(f"FCM sent successfully: {response}")
            return True
        except Exception as e:
            logger.error(f"FCM send failed: {e}")
            return False

    @staticmethod
    async def send_stamp_near_reward(
        fcm_token: str,
        store_name: str,
        current: int,
        goal: int,
    ) -> bool:
        """쿠폰 달성 임박 알림."""
        remaining = goal - current
        return await FCMService.send_push(
            fcm_token=fcm_token,
            title=f"🎯 {store_name}",
            body=f"도장 {remaining}개만 더 모으면 무료 혜택! ({current}/{goal})",
            data={"type": "near_reward", "store_name": store_name},
        )

    @staticmethod
    async def send_coupon_earned(
        fcm_token: str,
        store_name: str,
        reward: str,
    ) -> bool:
        """쿠폰 달성 완료 알림."""
        return await FCMService.send_push(
            fcm_token=fcm_token,
            title=f"🎉 축하해요! {store_name}",
            body=f"도장을 다 모았어요! '{reward}' 쿠폰을 확인하세요.",
            data={"type": "coupon_earned", "store_name": store_name},
        )

    @staticmethod
    async def send_coupon_expiring(
        fcm_token: str,
        store_name: str,
        days_left: int,
    ) -> bool:
        """쿠폰 만료 임박 알림."""
        return await FCMService.send_push(
            fcm_token=fcm_token,
            title=f"⏰ {store_name} 쿠폰 만료 임박!",
            body=f"{days_left}일 후 쿠폰이 만료돼요. 지금 사용하세요!",
            data={"type": "coupon_expiring", "store_name": store_name},
        )
