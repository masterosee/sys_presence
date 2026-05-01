import asyncio
import asyncpg
import bcrypt

async def main():
    h = bcrypt.hashpw(b'*abcd1234#', bcrypt.gensalt()).decode()
    conn = await asyncpg.connect(
        host='localhost',
        port=5432,
        user='postgres',
        password='Li2s9anq!',
        database='conatel_presence'
    )
    await conn.execute("""
        INSERT INTO users (employee_id, username, password_hash, role)
        VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ossinyb', $1, 'employee')
    """, h)
    await conn.close()
    print("Compte ossinyb créé!")

asyncio.run(main())

