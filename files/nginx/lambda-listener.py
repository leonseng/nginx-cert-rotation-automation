from fastapi import FastAPI, Response, status
from subprocess import run, CalledProcessError
import uvicorn

app = FastAPI()

@app.post("/update", status_code=201)
async def update(response: Response):
    try:
        # Run the bash command
        result = run(["/usr/local/bin/rotate-certs.sh"], capture_output=True, text=True, check=True)
        print(f"Success: {result.stdout}")
        return {"status": "success", "output": result.stdout}
    except CalledProcessError as e:
        print(f"Error: {e}")
        response.status_code = 500
        return {"status": "error", "output": e}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
