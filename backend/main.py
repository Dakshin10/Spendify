from fastapi import FastAPI
from backend.upload import router as upload_router
from backend.database import init_db

# Initialize database
init_db()

app = FastAPI(title="Spendify API")

@app.get("/")
def read_root():
    return {"status": "Spendify API is running!"}

app.include_router(upload_router)