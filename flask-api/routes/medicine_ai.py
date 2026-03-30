import os
import json
from google import genai
from flask import Blueprint, request, jsonify

medicine_ai_bp = Blueprint("medicine_ai", __name__)
client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

@medicine_ai_bp.route("/api/medicine/info", methods=["POST"])
def medicine_info():
    payload = request.get_json(silent=True) or {}
    medicine_name = payload.get("medicine_name", "").strip()

    if not medicine_name:
        return jsonify({"error": "medicine_name is required"}), 400

    try:
        prompt = f"""You are a medical information assistant.
Give concise factual info about: {medicine_name}
Respond ONLY with a JSON object, no extra text, no markdown:
{{
    "medicine": "<name>",
    "uses": "<what it treats>",
    "dosage": "<typical dosage>",
    "side_effects": "<common side effects>",
    "warnings": "<important warnings>"
}}"""
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt
        )
        raw = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        return jsonify(json.loads(raw)), 200

    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
