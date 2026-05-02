from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Uygulama
    APP_NAME: str = "AKSA"
    DEBUG: bool = False

    # PostgreSQL
    DATABASE_URL: str

    # JWT
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60

    # SMTP
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_EMAIL: str
    SMTP_PASSWORD: str

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_IOS_CLIENT_ID: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


settings = Settings()
