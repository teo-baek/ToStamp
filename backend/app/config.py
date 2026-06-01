"""
ToStamp Backend Configuration
환경변수 기반 설정 관리 (Pydantic Settings)
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # App
    app_name: str = "ToStamp API"
    app_version: str = "0.1.0"
    debug: bool = False
    api_prefix: str = "/api/v1"

    # Database
    database_url: str = "postgresql+asyncpg://tostamp:tostamp@localhost:5432/tostamp"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # JWT Auth
    jwt_secret_key: str = "dev-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60 * 24 * 7  # 7 days

    # QR Token
    qr_token_ttl_seconds: int = 180  # 3분

    # CORS
    cors_origins: list[str] = ["*"]

    # Firebase
    firebase_credentials_path: str | None = None

    # GCP
    gcp_project_id: str | None = None


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
