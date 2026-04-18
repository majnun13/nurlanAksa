import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://yavuz@localhost:5432/aksa')
    rows = await conn.fetch('SELECT name FROM food_items LIMIT 10')
    for row in rows:
        print(row['name'])
    await conn.close()

asyncio.run(main())
