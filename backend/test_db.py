import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def main():
    conn = await asyncpg.connect(os.getenv("DATABASE_URL"))
    rows = await conn.fetch("SELECT schema_name FROM information_schema.schemata")
    schemas = [r['schema_name'] for r in rows]
    print(f"Schemas: {schemas}")
    
    if "nurlanAksaV1" in schemas:
        tables = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema = 'nurlanAksaV1'")
        print(f"Tables in nurlanAksaV1: {[r['table_name'] for r in tables]}")
    else:
        print("Schema 'nurlanAksaV1' not found!")
    
    await conn.close()

asyncio.run(main())
