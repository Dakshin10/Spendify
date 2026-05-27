from fastapi import FastAPI
from backend.upload import router as upload_router

app = FastAPI(title="Spendify API")

@app.get("/")
def read_root():
    return {"status": "Spendify API is running!"}

app.include_router(upload_router)