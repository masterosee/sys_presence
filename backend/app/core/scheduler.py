# app/core/scheduler.py

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

scheduler = AsyncIOScheduler()


def start_scheduler():
    scheduler.start()
    print("✅ Scheduler démarré")


def stop_scheduler():
    scheduler.shutdown()
    print("✅ Scheduler arrêté")
    
    
