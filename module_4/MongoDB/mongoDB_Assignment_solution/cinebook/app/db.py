import os
from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient

load_dotenv()
client = AsyncIOMotorClient(os.environ["MONGODB_URI"])
db = client[os.getenv("MONGODB_DB", "cinebook")]


#  checking the connection
if __name__ == "__main__":
    import asyncio

    async def check():
        print(await client.admin.command("ping"))

    asyncio.run(check())