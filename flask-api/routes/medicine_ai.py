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
            model="gemini-2.5-flash",
            contents=prompt
        )
        raw = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        return jsonify(json.loads(raw)), 200

    except Exception as exc:
        return jsonify({"error": str(exc)}), 500

@medicine_ai_bp.route("/api/medicine/interactions", methods=["POST"])
def medicine_interactions():
    payload = request.get_json(silent=True) or {}
    medicine_1 = payload.get("medicine_1", "").strip()
    medicine_2 = payload.get("medicine_2", "").strip()

    if not medicine_1 or not medicine_2:
        return jsonify({"error": "medicine_1 and medicine_2 are required"}), 400

    try:
        prompt = f"""You are a medical information assistant.
Check for interactions between: {medicine_1} and {medicine_2}
Respond ONLY with a JSON object, no extra text, no markdown:
{{
    "medicine_1": "<name>",
    "medicine_2": "<name>",
    "interaction_exists": true or false,
    "severity": "<None/Mild/Moderate/Severe>",
    "description": "<what happens if taken together>",
    "recommendation": "<what the patient should do>"
}}"""
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        raw = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        return jsonify(json.loads(raw)), 200

    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@medicine_ai_bp.route("/api/medicine/alternatives", methods=["POST"])
def medicine_alternatives():
    payload = request.get_json(silent=True) or {}
    medicine_name = payload.get("medicine_name", "").strip()

    if not medicine_name:
        return jsonify({"error": "medicine_name is required"}), 400

    try:
        prompt = f"""You are a medical information assistant.
Suggest generic and branded alternatives for: {medicine_name}
Respond ONLY with a JSON object, no extra text, no markdown:
{{
    "medicine": "<name>",
    "alternatives": [
        {{
            "name": "<alternative name>",
            "type": "<Generic or Branded>",
            "notes": "<why it is a suitable alternative>"
        }}
    ]
}}"""
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        raw = response.text.strip().removeprefix("```json").removesuffix("```").strip()
        return jsonify(json.loads(raw)), 200

    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
