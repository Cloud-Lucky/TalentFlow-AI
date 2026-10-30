from flask import Flask, jsonify
from flask_cors import CORS
from .config import Config
from .extensions import db, jwt
from .routes import api


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})
    db.init_app(app)
    jwt.init_app(app)
    app.register_blueprint(api, url_prefix="/api")

    @app.get("/health")
    def health():
        return jsonify(status="ok", service="talentflow-api")

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error="Not found"), 404

    @app.errorhandler(413)
    def too_large(_):
        return jsonify(error="Request too large"), 413

    return app
