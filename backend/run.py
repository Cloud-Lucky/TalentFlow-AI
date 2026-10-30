import os
from app import create_app
from app.extensions import db

app = create_app()
with app.app_context():
    if os.environ.get("AUTO_CREATE_TABLES", "true").lower() == "true":
        db.create_all()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
