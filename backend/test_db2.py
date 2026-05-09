import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def main():
    try:
        conn = await asyncpg.connect(os.getenv("DATABASE_URL"), server_settings={'search_path': 'nurlanAksaV1'})
        row = await conn.fetchrow("SELECT * FROM users LIMIT 1")
        print("Success without quotes")
    except Exception as e:
        print(f"Error without quotes: {e}")

    try:
        conn2 = await asyncpg.connect(os.getenv("DATABASE_URL"), server_settings={'search_path': '"nurlanAksaV1"'})
        row2 = await conn2.fetchrow("SELECT * FROM users LIMIT 1")
        print("Success with quotes")
    except Exception as e:
        print(f"Error with quotes: {e}")

asyncio.run(main())
